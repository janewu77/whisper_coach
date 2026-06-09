"""Team membership helpers — access is granted to every member of a team
(via the UserTeam join), replacing the old single owner_id scoping."""

from sqlmodel import Session, select

from app.models import UserTeam


def is_member(session: Session, user_id: str, team_id: int) -> bool:
    return session.get(UserTeam, (user_id, team_id)) is not None


def team_ids_for(session: Session, user_id: str) -> list[int]:
    return list(
        session.exec(
            select(UserTeam.team_id).where(UserTeam.user_id == user_id)
        ).all()
    )


def add_member(session: Session, user_id: str, team_id: int) -> None:
    if not is_member(session, user_id, team_id):
        session.add(UserTeam(user_id=user_id, team_id=team_id))
