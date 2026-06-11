from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlmodel import Session, select

from app.agents.analyst import summarize_match
from app.agents.lineup import adjust_lineup, generate_lineup
from app.agents.match_extract import (
    extract_matches_from_image,
    extract_matches_from_text,
)
from app.agents.transcribe import transcribe_audio
from app import credits
from app.auth import current_auth0_id
from app.db import get_session
from app.membership import is_member, team_ids_for
from app.models import Lineup, Match, Note, Player, Team
from app.schemas import (
    AdjustResult,
    LineupRequest,
    LineupResult,
    LineupSlot,
    MatchExtractResult,
    MatchInput,
    MatchResponse,
    MatchUpdate,
    NoteInput,
    NoteOut,
    NoteResponse,
    PlayerOut,
    SummaryResult,
    VoiceNoteResponse,
)

router = APIRouter(prefix="/api/matches", tags=["matches"])


def _owned_match_or_404(session: Session, match_id: int, auth0_id: str) -> Match:
    """Fetch a match on a team the user belongs to, else 404."""
    match = session.get(Match, match_id)
    if not match or not is_member(session, auth0_id, match.team_id):
        raise HTTPException(status_code=404, detail="match not found")
    return match


def _latest_lineup(session: Session, match_id: int) -> Lineup | None:
    return session.exec(
        select(Lineup)
        .where(Lineup.match_id == match_id)
        .order_by(Lineup.created_at.desc())
    ).first()


def _to_lineup_result(row: Lineup) -> LineupResult:
    return LineupResult(
        formation=row.formation,
        lineup=[LineupSlot(**s) for s in row.slots],
        subs=[LineupSlot(**s) for s in (row.subs or [])],
        reason=row.reason,
    )


# Spelled-out position names → standard short codes (display safety net for
# lineups stored before the agent was told to emit codes).
_POSITION_CODES = {
    "goalkeeper": "GK",
    "keeper": "GK",
    "centre-back": "CB",
    "center-back": "CB",
    "centre back": "CB",
    "center back": "CB",
    "central defender": "CB",
    "left-back": "LB",
    "left back": "LB",
    "right-back": "RB",
    "right back": "RB",
    "left wing-back": "LWB",
    "left wingback": "LWB",
    "right wing-back": "RWB",
    "right wingback": "RWB",
    "defensive midfielder": "CDM",
    "holding midfielder": "CDM",
    "central midfielder": "CM",
    "centre midfielder": "CM",
    "midfielder": "CM",
    "attacking midfielder": "CAM",
    "left midfielder": "LM",
    "right midfielder": "RM",
    "left winger": "LW",
    "left wing": "LW",
    "right winger": "RW",
    "right wing": "RW",
    "striker": "ST",
    "centre forward": "ST",
    "center forward": "ST",
    "forward": "ST",
    "substitute": "SUB",
}


def _short_position(pos: str) -> str:
    p = pos.strip()
    mapped = _POSITION_CODES.get(p.casefold())
    if mapped:
        return mapped
    return p.upper() if len(p) <= 3 else p


def _absent_on(p: Player, date: str) -> bool:
    """Whether an absence range (inclusive YYYY-MM-DD) covers `date`."""
    for a in p.absences or []:
        try:
            if a["from"] <= date <= a["to"]:
                return True
        except (KeyError, TypeError):
            continue
    return False


def _available_players(
    session: Session, match: Match
) -> tuple[list[Player], list[Player]]:
    """The team roster split into (available, all) for this match. The coach's
    explicit per-match list wins; otherwise availability derives from each
    player's absence ranges on the match date."""
    players = list(
        session.exec(select(Player).where(Player.team_id == match.team_id)).all()
    )
    if match.unavailable_player_ids is not None:
        excluded = set(match.unavailable_player_ids)
        available = [p for p in players if p.id not in excluded]
    else:
        available = [p for p in players if not _absent_on(p, match.date)]
    return available, players


def _complete_squad(result: LineupResult, players: list[Player]) -> LineupResult:
    """Make the squad whole: canonicalize each slot to its roster player
    (matched by name OR nickname), attach nicknames, normalize positions to
    short codes, drop bench entries that duplicate a starter (or each other),
    and append every roster player the agent left out to the bench — starters
    + subs always cover the entire roster, each player exactly once."""

    def norm(s: str) -> str:
        return s.strip().casefold()

    by_name = {norm(p.name): p for p in players}
    by_nick = {norm(p.nickname): p for p in players if p.nickname}

    def enrich(slot: LineupSlot) -> None:
        slot.position = _short_position(slot.position)
        p = by_name.get(norm(slot.player)) or by_nick.get(norm(slot.player))
        if p is not None:
            # Canonicalize so dedup below compares the same roster identity
            # even when the agent wrote the nickname or a variant.
            slot.player = p.name
            if p.nickname:
                slot.nickname = p.nickname

    for slot in [*result.lineup, *result.subs]:
        enrich(slot)

    starters = {norm(s.player) for s in result.lineup}
    deduped: list[LineupSlot] = []
    seen: set[str] = set()
    for s in result.subs:
        key = norm(s.player)
        if key in starters or key in seen:
            continue  # already starting, or listed twice on the bench
        seen.add(key)
        deduped.append(s)
    result.subs = deduped

    used = starters | seen
    for p in players:
        if norm(p.name) not in used:
            result.subs.append(
                LineupSlot(
                    player=p.name,
                    position=_short_position(p.preferred_position or "SUB"),
                    nickname=p.nickname,
                )
            )
    return result


@router.post("", response_model=MatchResponse, status_code=201)
def create_match(
    body: MatchInput,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    # The match may only be created against a team the caller belongs to.
    if not is_member(session, auth0_id, body.team_id):
        raise HTTPException(status_code=404, detail="team not found")
    match = Match(**body.model_dump())
    session.add(match)
    session.commit()
    session.refresh(match)
    return MatchResponse(**match.model_dump())


@router.get("", response_model=list[MatchResponse])
def list_matches(
    team_id: int | None = None,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    team_ids = team_ids_for(session, auth0_id)
    if not team_ids:
        return []
    query = select(Match).where(Match.team_id.in_(team_ids))
    if team_id is not None:
        query = query.where(Match.team_id == team_id)
    matches = session.exec(query.order_by(Match.created_at.desc())).all()
    return [MatchResponse(**m.model_dump()) for m in matches]


@router.post("/extract", response_model=MatchExtractResult)
async def extract_matches(
    image: UploadFile = File(...),
    team_id: int = Form(...),
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    """Parse a fixtures photo into matches (not saved — the app reviews them)."""
    if not is_member(session, auth0_id, team_id):
        raise HTTPException(status_code=404, detail="team not found")
    if not (image.content_type or "").startswith("image/"):
        raise HTTPException(status_code=422, detail="image must be an image file")
    data = await image.read()
    try:
        result = await extract_matches_from_image(data, image.content_type)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"match extraction failed: {exc}")
    credits.charge_image(session, auth0_id, "Fixtures photo extraction")
    return result


@router.post("/extract/voice", response_model=MatchExtractResult)
async def extract_matches_voice(
    audio: UploadFile = File(...),
    team_id: int = Form(...),
    language: str | None = Form(None),
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    """Parse a spoken schedule into matches (not saved)."""
    if not is_member(session, auth0_id, team_id):
        raise HTTPException(status_code=404, detail="team not found")
    if not (audio.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=422, detail="audio must be an audio file")
    data = await audio.read()
    try:
        text = await transcribe_audio(data, audio.filename or "matches.webm", language)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"transcription failed: {exc}")
    try:
        result = await extract_matches_from_text(text)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"match extraction failed: {exc}")
    credits.charge_voice(session, auth0_id, "Spoken schedule extraction")
    return result


@router.get("/{match_id}")
def get_match(
    match_id: int,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    match = _owned_match_or_404(session, match_id, auth0_id)
    lineup = _latest_lineup(session, match_id)
    notes = session.exec(select(Note).where(Note.match_id == match_id)).all()
    if lineup:
        # Complete older stored lineups at read time (full bench + nicknames),
        # only drawing bench fill from players available for this match.
        available, _ = _available_players(session, match)
        lineup_out = _complete_squad(_to_lineup_result(lineup), available)
    return {
        **MatchResponse(**match.model_dump()).model_dump(),
        "lineup": lineup_out.model_dump() if lineup else None,
        "notes": [
            {"id": n.id, "kind": n.kind, "content": n.content, "ai_response": n.ai_response}
            for n in notes
        ],
    }


@router.delete("/{match_id}", status_code=204)
def delete_match(
    match_id: int,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    """Delete a match and its lineups/notes (owner-scoped via team membership)."""
    match = _owned_match_or_404(session, match_id, auth0_id)
    for note in session.exec(select(Note).where(Note.match_id == match_id)).all():
        session.delete(note)
    for lineup in session.exec(
        select(Lineup).where(Lineup.match_id == match_id)
    ).all():
        session.delete(lineup)
    session.delete(match)
    session.commit()


@router.patch("/{match_id}", response_model=MatchResponse)
def update_match(
    match_id: int,
    body: MatchUpdate,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    """Edit an existing match's fields (only provided fields change)."""
    match = _owned_match_or_404(session, match_id, auth0_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(match, field, value)
    session.add(match)
    session.commit()
    session.refresh(match)
    return MatchResponse(**match.model_dump())


async def _make_lineup(
    session: Session,
    auth0_id: str,
    match_id: int,
    strength: str | None,
    team_size: int | None,
    formation: str | None,
    instructions: str | None,
    language: str | None = None,
) -> LineupResult:
    """Shared generate-and-store path for the text and voice lineup routes.
    Does NOT charge credits — each route charges its own modality."""
    match = _owned_match_or_404(session, match_id, auth0_id)
    players, roster = _available_players(session, match)
    if not roster:
        raise HTTPException(status_code=409, detail="team has no players")
    if not players:
        raise HTTPException(
            status_code=409, detail="no players are available for this match"
        )

    player_outs = [
        PlayerOut(name=p.name, number=p.number, preferred_position=p.preferred_position)
        for p in players
    ]
    try:
        result = await generate_lineup(
            player_outs,
            match.opponent,
            strength or match.strength,
            team_size=team_size,
            formation=formation,
            instructions=instructions,
            language=language,
            venue=match.pitch or match.address or match.location or None,
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"lineup generation failed: {exc}")

    result = _complete_squad(result, players)
    session.add(
        Lineup(
            match_id=match_id,
            formation=result.formation,
            slots=[s.model_dump() for s in result.lineup],
            subs=[s.model_dump() for s in result.subs],
            reason=result.reason,
        )
    )
    session.commit()
    return result


@router.post("/{match_id}/lineup", response_model=LineupResult)
async def make_lineup(
    match_id: int,
    body: LineupRequest | None = None,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    body = body or LineupRequest()
    result = await _make_lineup(
        session,
        auth0_id,
        match_id,
        body.strength,
        body.team_size,
        body.formation,
        body.instructions,
        language=body.language,
    )
    match = session.get(Match, match_id)
    credits.charge_text(session, auth0_id, f"Lineup vs {match.opponent}")
    return result


@router.post("/{match_id}/lineup/voice", response_model=LineupResult)
async def make_lineup_voice(
    match_id: int,
    audio: UploadFile = File(...),
    team_size: int | None = Form(None),
    formation: str | None = Form(None),
    language: str | None = Form(None),
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    """Generate a lineup from spoken coach instructions (transcribed first)."""
    _owned_match_or_404(session, match_id, auth0_id)
    if not (audio.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=422, detail="audio must be an audio file")
    data = await audio.read()
    try:
        instructions = await transcribe_audio(
            data, audio.filename or "lineup.webm", language
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"transcription failed: {exc}")

    result = await _make_lineup(
        session,
        auth0_id,
        match_id,
        None,
        team_size,
        formation,
        instructions,
        language=language,
    )
    match = session.get(Match, match_id)
    credits.charge_voice(session, auth0_id, f"Lineup (voice) vs {match.opponent}")
    return result


async def _adjust_and_store(
    session: Session, match_id: int, auth0_id: str, kind: str, content: str
) -> tuple[Note, AdjustResult]:
    """Shared path for text and voice notes: run the adjust agent + persist."""
    _owned_match_or_404(session, match_id, auth0_id)
    lineup_row = _latest_lineup(session, match_id)
    if not lineup_row:
        raise HTTPException(
            status_code=409, detail="generate a lineup before adding notes"
        )

    try:
        suggestion = await adjust_lineup(_to_lineup_result(lineup_row), content)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"adjustment failed: {exc}")

    note = Note(
        match_id=match_id,
        kind=kind,
        content=content,
        ai_response=suggestion.model_dump(by_alias=True),
    )
    session.add(note)
    session.commit()
    session.refresh(note)
    return note, suggestion


@router.post("/{match_id}/notes", response_model=NoteResponse)
async def add_note(
    match_id: int,
    body: NoteInput,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    note, suggestion = await _adjust_and_store(
        session, match_id, auth0_id, body.kind, body.content
    )
    credits.charge_text(session, auth0_id, "Match note suggestion")
    return NoteResponse(note_id=note.id, suggestion=suggestion)


@router.get("/{match_id}/notes", response_model=list[NoteOut])
def list_notes(
    match_id: int,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    _owned_match_or_404(session, match_id, auth0_id)
    notes = session.exec(
        select(Note).where(Note.match_id == match_id).order_by(Note.created_at)
    ).all()
    return [
        NoteOut(id=n.id, kind=n.kind, content=n.content, ai_response=n.ai_response)
        for n in notes
    ]


@router.post("/{match_id}/notes/voice", response_model=VoiceNoteResponse)
async def add_voice_note(
    match_id: int,
    audio: UploadFile = File(...),
    language: str | None = Form(None),
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    """Upload an audio clip; it is transcribed, then treated like a text note."""
    _owned_match_or_404(session, match_id, auth0_id)
    if not (audio.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=422, detail="audio must be an audio file")

    data = await audio.read()
    try:
        text = await transcribe_audio(data, audio.filename or "note.webm", language)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"transcription failed: {exc}")

    note, suggestion = await _adjust_and_store(session, match_id, auth0_id, "voice", text)
    credits.charge_voice(session, auth0_id, "Voice note suggestion")
    return VoiceNoteResponse(
        note_id=note.id, transcription=text, suggestion=suggestion
    )


@router.post("/{match_id}/summary", response_model=SummaryResult)
async def make_summary(
    match_id: int,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    match = _owned_match_or_404(session, match_id, auth0_id)
    lineup_row = _latest_lineup(session, match_id)
    lineup = _to_lineup_result(lineup_row) if lineup_row else None
    notes = session.exec(select(Note).where(Note.match_id == match_id)).all()

    try:
        result = await summarize_match(lineup, [n.content for n in notes])
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"summary failed: {exc}")
    credits.charge_text(session, auth0_id, "Post-match summary")

    match.summary = result.model_dump()
    session.add(match)
    session.commit()
    return result


@router.get("/{match_id}/summary", response_model=SummaryResult)
def get_summary(
    match_id: int,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    """Return the stored summary; 404 if it hasn't been generated yet (POST first)."""
    match = _owned_match_or_404(session, match_id, auth0_id)
    if not match.summary:
        raise HTTPException(status_code=404, detail="summary not generated yet")
    return SummaryResult(**match.summary)
