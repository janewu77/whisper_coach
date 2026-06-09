from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlmodel import Session, select

from app.agents.analyst import summarize_match
from app.agents.lineup import adjust_lineup, generate_lineup
from app.agents.match_extract import (
    extract_matches_from_image,
    extract_matches_from_text,
)
from app.agents.transcribe import transcribe_audio
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
        reason=row.reason,
    )


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
        return await extract_matches_from_image(data, image.content_type)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"match extraction failed: {exc}")


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
        return await extract_matches_from_text(text)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"match extraction failed: {exc}")


@router.get("/{match_id}")
def get_match(
    match_id: int,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    match = _owned_match_or_404(session, match_id, auth0_id)
    lineup = _latest_lineup(session, match_id)
    notes = session.exec(select(Note).where(Note.match_id == match_id)).all()
    return {
        **MatchResponse(**match.model_dump()).model_dump(),
        "lineup": _to_lineup_result(lineup).model_dump() if lineup else None,
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


@router.post("/{match_id}/lineup", response_model=LineupResult)
async def make_lineup(
    match_id: int,
    body: LineupRequest | None = None,
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    match = _owned_match_or_404(session, match_id, auth0_id)
    players = session.exec(select(Player).where(Player.team_id == match.team_id)).all()
    if not players:
        raise HTTPException(status_code=409, detail="team has no players")

    strength = (body.strength if body else None) or match.strength
    player_outs = [
        PlayerOut(name=p.name, number=p.number, preferred_position=p.preferred_position)
        for p in players
    ]
    try:
        result = await generate_lineup(player_outs, match.opponent, strength)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"lineup generation failed: {exc}")

    session.add(
        Lineup(
            match_id=match_id,
            formation=result.formation,
            slots=[s.model_dump() for s in result.lineup],
            reason=result.reason,
        )
    )
    session.commit()
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
