from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlmodel import Session, select

from app.agents.analyst import summarize_match
from app.agents.lineup import adjust_lineup, generate_lineup
from app.agents.transcribe import transcribe_audio
from app.db import get_session
from app.models import Lineup, Match, Note, Player
from app.schemas import (
    AdjustResult,
    LineupRequest,
    LineupResult,
    LineupSlot,
    MatchInput,
    MatchResponse,
    NoteInput,
    NoteOut,
    NoteResponse,
    PlayerOut,
    SummaryResult,
    VoiceNoteResponse,
)

router = APIRouter(prefix="/api/matches", tags=["matches"])


def _match_or_404(session: Session, match_id: int) -> Match:
    match = session.get(Match, match_id)
    if not match:
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
def create_match(body: MatchInput, session: Session = Depends(get_session)):
    # team existence is not strictly required for the MVP
    match = Match(**body.model_dump())
    session.add(match)
    session.commit()
    session.refresh(match)
    return MatchResponse(**match.model_dump())


@router.get("", response_model=list[MatchResponse])
def list_matches(session: Session = Depends(get_session)):
    matches = session.exec(select(Match).order_by(Match.created_at.desc())).all()
    return [MatchResponse(**m.model_dump()) for m in matches]


@router.get("/{match_id}")
def get_match(match_id: int, session: Session = Depends(get_session)):
    match = _match_or_404(session, match_id)
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


@router.post("/{match_id}/lineup", response_model=LineupResult)
async def make_lineup(
    match_id: int,
    body: LineupRequest | None = None,
    session: Session = Depends(get_session),
):
    match = _match_or_404(session, match_id)
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
    session: Session, match_id: int, kind: str, content: str
) -> tuple[Note, AdjustResult]:
    """Shared path for text and voice notes: run the adjust agent + persist."""
    _match_or_404(session, match_id)
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
    match_id: int, body: NoteInput, session: Session = Depends(get_session)
):
    note, suggestion = await _adjust_and_store(
        session, match_id, body.kind, body.content
    )
    return NoteResponse(note_id=note.id, suggestion=suggestion)


@router.get("/{match_id}/notes", response_model=list[NoteOut])
def list_notes(match_id: int, session: Session = Depends(get_session)):
    _match_or_404(session, match_id)
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
    session: Session = Depends(get_session),
):
    """Upload an audio clip; it is transcribed, then treated like a text note."""
    _match_or_404(session, match_id)
    if not (audio.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=422, detail="audio must be an audio file")

    data = await audio.read()
    try:
        text = await transcribe_audio(data, audio.filename or "note.webm")
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"transcription failed: {exc}")

    note, suggestion = await _adjust_and_store(session, match_id, "voice", text)
    return VoiceNoteResponse(
        note_id=note.id, transcription=text, suggestion=suggestion
    )


@router.post("/{match_id}/summary", response_model=SummaryResult)
async def make_summary(match_id: int, session: Session = Depends(get_session)):
    match = _match_or_404(session, match_id)
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
def get_summary(match_id: int, session: Session = Depends(get_session)):
    """Return the stored summary; 404 if it hasn't been generated yet (POST first)."""
    match = _match_or_404(session, match_id)
    if not match.summary:
        raise HTTPException(status_code=404, detail="summary not generated yet")
    return SummaryResult(**match.summary)
