"""Roster import review: stage an OCR/AI import in memory, let the coach review &
correct it, and only write to the live roster on explicit confirmation.

The review session is an in-memory buffer (app/services/import_store.py) — the DB
is only read here (Team/Player) and written once, on POST .../confirm. All routes
are owner-scoped (a session is reachable only by its owner).
"""

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlmodel import Session, select

from app.agents.import_editor import parse_command
from app.agents.roster import extract_players_from_text, extract_roster
from app.agents.transcribe import transcribe_audio
from app.auth import current_user_id
from app.db import get_session
from app.membership import is_member
from app.models import Player, Team
from app.schemas import (
    CommandRequest,
    ConfirmResponse,
    ImportItemEdit,
    ImportReviewResponse,
    MergeRequest,
)
from app.services.import_review import (
    build_review,
    classify_imported,
    normalize,
    recompute_against_match,
)
from app.services.import_store import MemItem, MemSession, store

router = APIRouter(prefix="/api", tags=["imports"])


# ── helpers ──────────────────────────────────────────────────────────────────


def _owned_team_or_404(db: Session, team_id: int, user_id: str) -> Team:
    team = db.get(Team, team_id)
    if not team or not is_member(db, user_id, team_id):
        raise HTTPException(status_code=404, detail="team not found")
    return team


def _owned_session_or_404(session_id: int, user_id: str) -> MemSession:
    imp = store.get(session_id)
    if not imp or imp.owner_id != user_id:
        raise HTTPException(status_code=404, detail="import session not found")
    return imp


def _item_or_404(imp: MemSession, item_id: int) -> MemItem:
    item = imp.item(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="import item not found")
    return item


def _existing_players(db: Session, team_id: int) -> list[Player]:
    return list(db.exec(select(Player).where(Player.team_id == team_id)).all())


def _review(
    db: Session, imp: MemSession, reply: str | None = None
) -> ImportReviewResponse:
    existing_by_id = {p.id: p for p in _existing_players(db, imp.team_id)}
    return build_review(imp, existing_by_id, reply=reply)


# ── create a review from an uploaded photo ───────────────────────────────────


@router.post("/teams/{team_id}/imports", response_model=ImportReviewResponse)
async def create_import(
    team_id: int,
    image: UploadFile = File(...),
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    _owned_team_or_404(db, team_id, user_id)
    if not (image.content_type or "").startswith("image/"):
        raise HTTPException(status_code=422, detail="image must be an image file")

    data = await image.read()
    try:
        extracted = await extract_roster(data, image.content_type)
    except Exception as exc:  # noqa: BLE001 — surface any LLM/agent failure
        raise HTTPException(status_code=502, detail=f"roster extraction failed: {exc}")

    imp = await _stage_players(db, team_id, user_id, extracted.players)
    return _review(db, imp)


async def _stage_players(db: Session, team_id: int, user_id: str, players):
    """Supersede any pending session for the team and stage `players` for review."""
    for stale in store.pending_for_team(user_id, team_id):
        stale.status = "discarded"
    imp = store.create(owner_id=user_id, team_id=team_id)
    existing = _existing_players(db, team_id)
    imp.items = await classify_imported(players, existing, store.new_item_id)
    return imp


@router.post("/teams/{team_id}/imports/text", response_model=ImportReviewResponse)
async def create_import_from_text(
    team_id: int,
    body: CommandRequest,
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    """Stage players the coach describes in free text (e.g. dictated names)."""
    _owned_team_or_404(db, team_id, user_id)
    if not body.text.strip():
        raise HTTPException(status_code=422, detail="text is required")
    try:
        extracted = await extract_players_from_text(body.text)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"player extraction failed: {exc}")
    imp = await _stage_players(db, team_id, user_id, extracted.players)
    return _review(db, imp)


@router.post("/teams/{team_id}/imports/voice", response_model=ImportReviewResponse)
async def create_import_from_voice(
    team_id: int,
    audio: UploadFile = File(...),
    language: str | None = Form(None),
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    """Stage players from a spoken description (audio → transcribe → extract)."""
    _owned_team_or_404(db, team_id, user_id)
    if not (audio.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=422, detail="audio must be an audio file")
    data = await audio.read()
    try:
        text = await transcribe_audio(data, audio.filename or "players.webm", language)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"transcription failed: {exc}")
    try:
        extracted = await extract_players_from_text(text)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"player extraction failed: {exc}")
    imp = await _stage_players(db, team_id, user_id, extracted.players)
    return _review(db, imp)


# ── read ─────────────────────────────────────────────────────────────────────


@router.get("/imports/{session_id}", response_model=ImportReviewResponse)
def get_import(
    session_id: int,
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    imp = _owned_session_or_404(session_id, user_id)
    return _review(db, imp)


# ── edit / delete / merge one item ───────────────────────────────────────────


def _reclassify_resolved(db: Session, imp: MemSession, item: MemItem) -> None:
    """Recompute a non-duplicate item after an edit: exact-name match against the
    existing roster decides new vs updated/unchanged. Duplicates are left for the
    coach to resolve via merge."""
    if item.classification == "duplicate":
        return
    by_norm: dict[str, Player] = {}
    for p in _existing_players(db, imp.team_id):
        by_norm.setdefault(normalize(p.name), p)
    recompute_against_match(item, by_norm.get(normalize(item.name)))


@router.patch("/imports/{session_id}/items/{item_id}", response_model=ImportReviewResponse)
def edit_item(
    session_id: int,
    item_id: int,
    body: ImportItemEdit,
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    imp = _owned_session_or_404(session_id, user_id)
    item = _item_or_404(imp, item_id)
    if body.name is not None:
        item.name = body.name
    if body.number is not None:
        item.number = body.number
    if body.preferred_position is not None:
        item.preferred_position = body.preferred_position
    _reclassify_resolved(db, imp, item)
    return _review(db, imp)


@router.delete("/imports/{session_id}/items/{item_id}", response_model=ImportReviewResponse)
def delete_item(
    session_id: int,
    item_id: int,
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    imp = _owned_session_or_404(session_id, user_id)
    item = _item_or_404(imp, item_id)
    item.deleted = True
    return _review(db, imp)


@router.post(
    "/imports/{session_id}/items/{item_id}/merge",
    response_model=ImportReviewResponse,
)
def merge_item(
    session_id: int,
    item_id: int,
    body: MergeRequest,
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    imp = _owned_session_or_404(session_id, user_id)
    item = _item_or_404(imp, item_id)
    _apply_merge(db, imp, item, body.target_player_id, body.target_item_id)
    return _review(db, imp)


def _apply_merge(
    db: Session,
    imp: MemSession,
    item: MemItem,
    target_player_id: int | None,
    target_item_id: int | None,
) -> None:
    """Resolve `item` as a duplicate: link it to an existing player (it becomes
    an update/unchanged), or fold it into another import item (it is removed and
    its missing fields fill the survivor)."""
    if target_player_id is not None:
        player = db.get(Player, target_player_id)
        if not player or player.team_id != imp.team_id:
            raise HTTPException(status_code=404, detail="target player not found")
        recompute_against_match(item, player)
        item.rationale = None
        return

    if target_item_id is not None:
        target = _item_or_404(imp, target_item_id)
        if target.id == item.id:
            raise HTTPException(status_code=422, detail="cannot merge an item into itself")
        # Survivor (target) keeps its values; fill blanks from the folded item.
        if target.number is None:
            target.number = item.number
        if not target.preferred_position:
            target.preferred_position = item.preferred_position
        item.deleted = True
        return

    raise HTTPException(
        status_code=422, detail="provide target_player_id or target_item_id"
    )


# ── natural-language / voice commands ────────────────────────────────────────


def _apply_actions(db: Session, imp: MemSession, result) -> None:
    """Apply a parsed CommandResult's actions to the session's items."""
    for action in result.actions:
        item = imp.item(action.item_id)
        if not item:
            continue  # skip actions referencing unknown items
        if action.type == "delete":
            item.deleted = True
        elif action.type == "edit":
            if action.name is not None:
                item.name = action.name
            if action.number is not None:
                item.number = action.number
            if action.preferred_position is not None:
                item.preferred_position = action.preferred_position
            _reclassify_resolved(db, imp, item)
        elif action.type == "merge":
            _apply_merge(db, imp, item, action.target_player_id, action.target_item_id)


async def _run_command(
    db: Session, imp: MemSession, text: str
) -> ImportReviewResponse:
    items = [it for it in imp.items if not it.deleted]
    item_dicts = [
        {
            "id": it.id,
            "name": it.name,
            "number": it.number,
            "preferred_position": it.preferred_position,
            "classification": it.classification,
        }
        for it in items
    ]
    existing = _existing_players(db, imp.team_id)
    existing_dicts = [{"id": p.id, "name": p.name} for p in existing]
    try:
        result = await parse_command(text, item_dicts, existing_dicts)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"command parsing failed: {exc}")
    _apply_actions(db, imp, result)
    return _review(db, imp, reply=result.reply)


@router.post("/imports/{session_id}/command", response_model=ImportReviewResponse)
async def run_command(
    session_id: int,
    body: CommandRequest,
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    imp = _owned_session_or_404(session_id, user_id)
    return await _run_command(db, imp, body.text)


@router.post("/imports/{session_id}/command/voice", response_model=ImportReviewResponse)
async def run_voice_command(
    session_id: int,
    audio: UploadFile = File(...),
    language: str | None = Form(None),
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    imp = _owned_session_or_404(session_id, user_id)
    if not (audio.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=422, detail="audio must be an audio file")
    data = await audio.read()
    try:
        text = await transcribe_audio(data, audio.filename or "command.webm", language)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"transcription failed: {exc}")
    return await _run_command(db, imp, text)


# ── confirm: write to the live roster ────────────────────────────────────────


@router.post("/imports/{session_id}/confirm", response_model=ConfirmResponse)
def confirm_import(
    session_id: int,
    db: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    imp = _owned_session_or_404(session_id, user_id)
    if imp.status != "pending":
        raise HTTPException(status_code=409, detail="import already finalized")

    created = updated = skipped = 0
    for item in imp.items:
        if item.deleted:
            continue
        if item.classification == "unchanged":
            skipped += 1
            continue
        if item.classification == "updated" and item.match_player_id is not None:
            player = db.get(Player, item.match_player_id)
            if player and player.team_id == imp.team_id:
                player.name = item.name
                player.number = item.number
                player.preferred_position = item.preferred_position
                db.add(player)
                updated += 1
                continue
        # "new" and unresolved "duplicate" candidates become new players.
        db.add(
            Player(
                team_id=imp.team_id,
                name=item.name,
                number=item.number,
                preferred_position=item.preferred_position,
            )
        )
        created += 1

    imp.status = "confirmed"
    db.commit()
    return ConfirmResponse(created=created, updated=updated, skipped=skipped)
