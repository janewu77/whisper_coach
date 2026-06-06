from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.agents.analyst import summarize_match
from app.agents.lineup import adjust_lineup, generate_lineup
from app.db import get_session
from app.models import Lineup, Match, Note, Player
from app.schemas import (
    LineupRequest,
    LineupResult,
    LineupSlot,
    MatchInput,
    MatchResponse,
    NoteInput,
    NoteResponse,
    PlayerOut,
    SummaryResult,
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


@router.post("/{match_id}/notes", response_model=NoteResponse)
async def add_note(
    match_id: int, body: NoteInput, session: Session = Depends(get_session)
):
    _match_or_404(session, match_id)
    lineup_row = _latest_lineup(session, match_id)
    if not lineup_row:
        raise HTTPException(
            status_code=409, detail="generate a lineup before adding notes"
        )

    try:
        suggestion = await adjust_lineup(_to_lineup_result(lineup_row), body.content)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"adjustment failed: {exc}")

    note = Note(
        match_id=match_id,
        kind=body.kind,
        content=body.content,
        ai_response=suggestion.model_dump(by_alias=True),
    )
    session.add(note)
    session.commit()
    session.refresh(note)
    return NoteResponse(note_id=note.id, suggestion=suggestion)


@router.post("/{match_id}/summary", response_model=SummaryResult)
async def make_summary(match_id: int, session: Session = Depends(get_session)):
    _match_or_404(session, match_id)
    lineup_row = _latest_lineup(session, match_id)
    lineup = _to_lineup_result(lineup_row) if lineup_row else None
    notes = session.exec(select(Note).where(Note.match_id == match_id)).all()

    try:
        result = await summarize_match(lineup, [n.content for n in notes])
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"summary failed: {exc}")
    return result
