"""Team membership helpers — access is granted to every member of a team
(via the UserTeam join), replacing the old single owner_id scoping."""

from sqlmodel import Session, select

from app.models import UserTeam


def is_member(session: Session, auth0_id: str, team_id: int) -> bool:
    return session.get(UserTeam, (auth0_id, team_id)) is not None


def team_ids_for(session: Session, auth0_id: str) -> list[int]:
    return list(
        session.exec(
            select(UserTeam.team_id).where(UserTeam.auth0_id == auth0_id)
        ).all()
    )


def add_member(session: Session, auth0_id: str, team_id: int) -> None:
    if not is_member(session, auth0_id, team_id):
        session.add(UserTeam(auth0_id=auth0_id, team_id=team_id))
