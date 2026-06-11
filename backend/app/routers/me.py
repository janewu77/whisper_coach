from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app import credits
from app.agents.style_distiller import distill_style
from app.auth import current_auth0_id, get_current_user
from app.db import get_session
from app.models import User
from app.schemas import (
    MeResponse,
    MeUpdate,
    StyleDistillRequest,
    SummaryStyleResponse,
)

router = APIRouter(prefix="/api", tags=["auth"])


@router.get("/me", response_model=MeResponse)
def get_me(
    claims: dict = Depends(get_current_user),
    auth0_id: str = Depends(current_auth0_id),
    session: Session = Depends(get_session),
):
    """Return the authenticated user (registered on first request).

    name/email come from the stored `users` row; if not set yet they fall back
    to the access-token claims (often absent — the app fills them via PATCH).
    """
    user = session.exec(select(User).where(User.auth0_id == auth0_id)).first()
    return MeResponse(
        sub=auth0_id,
        email=(user.email if user else None) or claims.get("email"),
        name=(user.name if user else None) or claims.get("name"),
        picture=claims.get("picture"),
    )


@router.patch("/me", response_model=MeResponse)
def update_me(
    body: MeUpdate,
    claims: dict = Depends(get_current_user),
    auth0_id: str = Depends(current_auth0_id),
    session: Session = Depends(get_session),
):
    """Update the current user's name/email (only non-empty fields change).

    The app calls this on login to fill missing name/email from the Auth0
    profile, and from the Profile screen when the user edits their name.
    """
    user = session.exec(select(User).where(User.auth0_id == auth0_id)).first()
    if body.name is not None and body.name.strip():
        user.name = body.name.strip()
    if body.email is not None and body.email.strip():
        user.email = body.email.strip()
    session.add(user)
    session.commit()
    session.refresh(user)
    return MeResponse(
        sub=auth0_id, email=user.email, name=user.name, picture=claims.get("picture")
    )


# ── Personal report style (used by every AI match summary) ──────────────────


def _me(session: Session, auth0_id: str) -> User:
    return session.exec(select(User).where(User.auth0_id == auth0_id)).first()


@router.get("/me/summary-style", response_model=SummaryStyleResponse)
def get_summary_style(
    auth0_id: str = Depends(current_auth0_id),
    session: Session = Depends(get_session),
):
    user = _me(session, auth0_id)
    return SummaryStyleResponse(
        style_card=user.summary_style_card if user else None,
        samples=user.summary_style_samples if user else None,
    )


@router.post("/me/summary-style", response_model=SummaryStyleResponse)
async def distill_summary_style(
    body: StyleDistillRequest,
    auth0_id: str = Depends(current_auth0_id),
    session: Session = Depends(get_session),
):
    """Distill pasted example texts into a style card and store both. Every
    match summary is then written in this voice."""
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="text is required")
    try:
        result = await distill_style(text)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"style distillation failed: {exc}")
    credits.charge_text(session, auth0_id, "Report style distillation")

    user = _me(session, auth0_id)
    user.summary_style_samples = text
    user.summary_style_card = result.style_card
    session.add(user)
    session.commit()
    return SummaryStyleResponse(style_card=result.style_card, samples=text)


@router.delete("/me/summary-style", status_code=204)
def delete_summary_style(
    auth0_id: str = Depends(current_auth0_id),
    session: Session = Depends(get_session),
):
    user = _me(session, auth0_id)
    if user is not None:
        user.summary_style_samples = None
        user.summary_style_card = None
        session.add(user)
        session.commit()
