from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlmodel import Session, select

from app.agents.player_profile import extract_profile
from app.agents.roster import extract_roster
from app.agents.transcribe import transcribe_audio
from app.auth import current_user_id
from app.db import get_session
from app.models import Player, Team
from app.schemas import (
    DescribeRequest,
    PlayerDetail,
    PlayerProfileResult,
    PlayerUpdate,
    RosterResponse,
    TeamCreate,
    TeamPlayer,
    TeamResponse,
    TeamSummary,
)


def _owned_player_or_404(
    session: Session, team_id: int, player_id: int, user_id: str
) -> Player:
    team = session.get(Team, team_id)
    if not team or team.owner_id != user_id:
        raise HTTPException(status_code=404, detail="team not found")
    player = session.get(Player, player_id)
    if not player or player.team_id != team_id:
        raise HTTPException(status_code=404, detail="player not found")
    return player


def _to_detail(p: Player) -> PlayerDetail:
    return PlayerDetail(
        id=p.id,
        name=p.name,
        number=p.number,
        preferred_position=p.preferred_position,
        positions=p.positions or [],
        preferred_foot=p.preferred_foot,
        height_cm=p.height_cm,
        traits=p.traits or [],
        description=p.description,
    )


def _profile_dict(p: Player) -> dict:
    return {
        "number": p.number,
        "positions": p.positions or [],
        "preferred_foot": p.preferred_foot,
        "height_cm": p.height_cm,
        "traits": p.traits or [],
        "description": p.description,
    }


def _union(existing: list[str], extra: list[str]) -> list[str]:
    """Order-preserving, case-insensitive union of string tags."""
    out: list[str] = []
    seen: set[str] = set()
    for v in [*(existing or []), *(extra or [])]:
        k = v.strip().casefold()
        if k and k not in seen:
            seen.add(k)
            out.append(v)
    return out


def _merge_detail(player: Player, prof: PlayerProfileResult) -> PlayerDetail:
    """Merge an extracted profile onto a player WITHOUT persisting — the client
    drops this into the edit form and saves explicitly."""
    positions = _union(player.positions or [], prof.positions)
    traits = _union(player.traits or [], prof.traits)
    return PlayerDetail(
        id=player.id,
        name=player.name,
        number=prof.number if prof.number is not None else player.number,
        preferred_position=positions[0] if positions else player.preferred_position,
        positions=positions,
        preferred_foot=prof.preferred_foot or player.preferred_foot,
        height_cm=prof.height_cm if prof.height_cm is not None else player.height_cm,
        traits=traits,
        description=prof.description or player.description,
    )

router = APIRouter(prefix="/api", tags=["roster"])


@router.get("/teams", response_model=list[TeamSummary])
def list_teams(
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    teams = session.exec(
        select(Team).where(Team.owner_id == user_id).order_by(Team.created_at)
    ).all()
    return [TeamSummary(id=t.id, name=t.name) for t in teams]


@router.post("/teams", response_model=TeamSummary, status_code=201)
def create_team(
    body: TeamCreate,
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="team name is required")
    team = Team(name=name, owner_id=user_id)
    session.add(team)
    session.commit()
    session.refresh(team)
    return TeamSummary(id=team.id, name=team.name)


@router.post("/roster/extract", response_model=RosterResponse)
async def roster_extract(
    image: UploadFile = File(...),
    team_name: str = Form("My Team"),
    team_id: int | None = Form(None),
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    if not (image.content_type or "").startswith("image/"):
        raise HTTPException(status_code=422, detail="image must be an image file")

    # Append to an existing team the caller owns, or create a fresh one.
    if team_id is not None:
        team = session.get(Team, team_id)
        if not team or team.owner_id != user_id:
            raise HTTPException(status_code=404, detail="team not found")
    else:
        team = Team(name=team_name, owner_id=user_id)
        session.add(team)
        session.commit()
        session.refresh(team)

    data = await image.read()
    try:
        result = await extract_roster(data, image.content_type)
    except Exception as exc:  # noqa: BLE001 — surface any LLM/agent failure
        raise HTTPException(status_code=502, detail=f"roster extraction failed: {exc}")

    for p in result.players:
        session.add(
            Player(
                team_id=team.id,
                name=p.name,
                number=p.number,
                preferred_position=p.preferred_position,
            )
        )
    session.commit()

    return RosterResponse(team_id=team.id, players=result.players)


@router.get("/teams/{team_id}", response_model=TeamResponse)
def get_team(
    team_id: int,
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    team = session.get(Team, team_id)
    if not team or team.owner_id != user_id:
        raise HTTPException(status_code=404, detail="team not found")
    players = session.exec(select(Player).where(Player.team_id == team_id)).all()
    return TeamResponse(
        id=team.id,
        name=team.name,
        players=[
            TeamPlayer(
                id=p.id,
                name=p.name,
                number=p.number,
                preferred_position=p.preferred_position,
            )
            for p in players
        ],
    )


@router.get("/teams/{team_id}/players/{player_id}", response_model=PlayerDetail)
def get_player(
    team_id: int,
    player_id: int,
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    return _to_detail(_owned_player_or_404(session, team_id, player_id, user_id))


@router.patch("/teams/{team_id}/players/{player_id}", response_model=PlayerDetail)
def update_player(
    team_id: int,
    player_id: int,
    body: PlayerUpdate,
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    """Manually edit a player's profile (only provided fields change)."""
    player = _owned_player_or_404(session, team_id, player_id, user_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(player, field, value)
    session.add(player)
    session.commit()
    session.refresh(player)
    return _to_detail(player)


@router.delete("/teams/{team_id}/players/{player_id}", status_code=204)
def delete_player(
    team_id: int,
    player_id: int,
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    """Remove a single player from a team's roster (owner-scoped)."""
    player = _owned_player_or_404(session, team_id, player_id, user_id)
    session.delete(player)
    session.commit()


@router.post(
    "/teams/{team_id}/players/{player_id}/describe",
    response_model=PlayerDetail,
)
async def describe_player(
    team_id: int,
    player_id: int,
    body: DescribeRequest,
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    """Merge a typed description into the profile and return it (NO save — the
    client drops the result into the form, then PATCHes to persist)."""
    player = _owned_player_or_404(session, team_id, player_id, user_id)
    if not body.text.strip():
        raise HTTPException(status_code=422, detail="text is required")
    try:
        prof = await extract_profile(body.text, _profile_dict(player))
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"profiling failed: {exc}")
    return _merge_detail(player, prof)


@router.post(
    "/teams/{team_id}/players/{player_id}/describe/voice",
    response_model=PlayerDetail,
)
async def describe_player_voice(
    team_id: int,
    player_id: int,
    audio: UploadFile = File(...),
    language: str | None = Form(None),
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    """Like /describe, but from a spoken description (audio → transcribe → extract)."""
    player = _owned_player_or_404(session, team_id, player_id, user_id)
    if not (audio.content_type or "").startswith("audio/"):
        raise HTTPException(status_code=422, detail="audio must be an audio file")
    data = await audio.read()
    try:
        text = await transcribe_audio(data, audio.filename or "profile.webm", language)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"transcription failed: {exc}")
    try:
        prof = await extract_profile(text, _profile_dict(player))
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"profiling failed: {exc}")
    return _merge_detail(player, prof)
