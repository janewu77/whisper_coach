from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlmodel import Session, select

from app.agents.roster import extract_roster
from app.auth import current_user_id
from app.db import get_session
from app.models import Player, Team
from app.schemas import (
    RosterResponse,
    TeamCreate,
    TeamPlayer,
    TeamResponse,
    TeamSummary,
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


@router.delete("/teams/{team_id}/players/{player_id}", status_code=204)
def delete_player(
    team_id: int,
    player_id: int,
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    """Remove a single player from a team's roster (owner-scoped)."""
    team = session.get(Team, team_id)
    if not team or team.owner_id != user_id:
        raise HTTPException(status_code=404, detail="team not found")
    player = session.get(Player, player_id)
    if not player or player.team_id != team_id:
        raise HTTPException(status_code=404, detail="player not found")
    session.delete(player)
    session.commit()
