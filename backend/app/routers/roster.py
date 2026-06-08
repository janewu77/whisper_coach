from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlmodel import Session, select

from app.agents.roster import extract_roster
from app.auth import current_user_id
from app.db import get_session
from app.models import Player, Team
from app.schemas import PlayerOut, RosterResponse, TeamResponse

router = APIRouter(prefix="/api", tags=["roster"])


@router.post("/roster/extract", response_model=RosterResponse)
async def roster_extract(
    image: UploadFile = File(...),
    team_name: str = Form("My Team"),
    session: Session = Depends(get_session),
    user_id: str = Depends(current_user_id),
):
    if not (image.content_type or "").startswith("image/"):
        raise HTTPException(status_code=422, detail="image must be an image file")

    data = await image.read()
    try:
        result = await extract_roster(data, image.content_type)
    except Exception as exc:  # noqa: BLE001 — surface any LLM/agent failure
        raise HTTPException(status_code=502, detail=f"roster extraction failed: {exc}")

    team = Team(name=team_name, owner_id=user_id)
    session.add(team)
    session.commit()
    session.refresh(team)

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
            PlayerOut(
                name=p.name, number=p.number, preferred_position=p.preferred_position
            )
            for p in players
        ],
    )
