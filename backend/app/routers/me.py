from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.auth import current_user_id, get_current_user
from app.db import get_session
from app.models import User
from app.schemas import MeResponse, MeUpdate

router = APIRouter(prefix="/api", tags=["auth"])


@router.get("/me", response_model=MeResponse)
def get_me(
    claims: dict = Depends(get_current_user),
    user_id: str = Depends(current_user_id),
    session: Session = Depends(get_session),
):
    """Return the authenticated user (registered on first request).

    name/email come from the stored `users` row; if not set yet they fall back
    to the access-token claims (often absent — the app fills them via PATCH).
    """
    user = session.exec(select(User).where(User.auth0_id == user_id)).first()
    return MeResponse(
        sub=user_id,
        email=(user.email if user else None) or claims.get("email"),
        name=(user.name if user else None) or claims.get("name"),
        picture=claims.get("picture"),
    )


@router.patch("/me", response_model=MeResponse)
def update_me(
    body: MeUpdate,
    claims: dict = Depends(get_current_user),
    user_id: str = Depends(current_user_id),
    session: Session = Depends(get_session),
):
    """Update the current user's name/email (only non-empty fields change).

    The app calls this on login to fill missing name/email from the Auth0
    profile, and from the Profile screen when the user edits their name.
    """
    user = session.exec(select(User).where(User.auth0_id == user_id)).first()
    if body.name is not None and body.name.strip():
        user.name = body.name.strip()
    if body.email is not None and body.email.strip():
        user.email = body.email.strip()
    session.add(user)
    session.commit()
    session.refresh(user)
    return MeResponse(
        sub=user_id, email=user.email, name=user.name, picture=claims.get("picture")
    )
