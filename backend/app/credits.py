"""Credit ledger.

Every user is granted ``INITIAL_CREDITS`` the first time they log in, and every
LLM-backed API call spends credits by the primary input modality:

    text  → 1 credit
    image → 5 credits
    voice → 2 credits   (a voice call bundles transcription + the follow-up LLM)

``User.credits`` is the running balance; ``CreditTransaction`` is the append-only
ledger. Spends are charged up front (before the LLM call) so a user with an empty
balance is rejected with HTTP 402 instead of triggering a paid API call.
"""

from typing import Optional

from fastapi import HTTPException, status
from sqlmodel import Session, select

from app.models import CreditTransaction, User

INITIAL_CREDITS = 100

# Cost per LLM call, keyed by the modality used as the transaction `kind`.
COST_TEXT = 1
COST_IMAGE = 5
COST_VOICE = 2


def _user(session: Session, auth0_id: str) -> Optional[User]:
    return session.exec(select(User).where(User.auth0_id == auth0_id)).first()


def balance(session: Session, auth0_id: str) -> int:
    user = _user(session, auth0_id)
    return user.credits if user else 0


def grant(
    session: Session,
    auth0_id: str,
    amount: int,
    kind: str,
    description: Optional[str] = None,
) -> int:
    """Add credits and record the grant. Commits."""
    user = _user(session, auth0_id)
    if user is None:
        raise HTTPException(status_code=404, detail="user not found")
    user.credits += amount
    session.add(user)
    session.add(
        CreditTransaction(
            auth0_id=auth0_id,
            amount=amount,
            balance_after=user.credits,
            kind=kind,
            description=description,
        )
    )
    session.commit()
    return user.credits


def grant_initial(session: Session, auth0_id: str) -> int:
    """Grant the one-time welcome credits to a brand-new user."""
    return grant(session, auth0_id, INITIAL_CREDITS, "initial", "Welcome credits")


def ensure_initial_grant(session: Session, auth0_id: str) -> int:
    """Grant the welcome credits if this user never received them.

    A safety net for accounts that predate the credits system (created before
    the migration backfill, or seeded outside the normal register path): the
    ledger is checked for an ``initial`` entry, so a user who legitimately
    spent down to zero is never re-granted."""
    already = session.exec(
        select(CreditTransaction).where(
            CreditTransaction.auth0_id == auth0_id,
            CreditTransaction.kind == "initial",
        )
    ).first()
    if already is not None:
        return balance(session, auth0_id)
    return grant_initial(session, auth0_id)


def _charge(
    session: Session, auth0_id: str, cost: int, kind: str, description: str
) -> int:
    """Spend `cost` credits for an LLM call; 402 if the balance is too low.
    Records the spend and commits. Returns the new balance."""
    user = _user(session, auth0_id)
    if user is None or user.credits < cost:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="Not enough credits for this action",
        )
    user.credits -= cost
    session.add(user)
    session.add(
        CreditTransaction(
            auth0_id=auth0_id,
            amount=-cost,
            balance_after=user.credits,
            kind=kind,
            description=description,
        )
    )
    session.commit()
    return user.credits


def charge_text(session: Session, auth0_id: str, description: str) -> int:
    return _charge(session, auth0_id, COST_TEXT, "text", description)


def charge_image(session: Session, auth0_id: str, description: str) -> int:
    return _charge(session, auth0_id, COST_IMAGE, "image", description)


def charge_voice(session: Session, auth0_id: str, description: str) -> int:
    return _charge(session, auth0_id, COST_VOICE, "voice", description)


def transactions(session: Session, auth0_id: str) -> list[CreditTransaction]:
    """The user's ledger, newest first."""
    return list(
        session.exec(
            select(CreditTransaction)
            .where(CreditTransaction.auth0_id == auth0_id)
            .order_by(CreditTransaction.created_at.desc(), CreditTransaction.id.desc())
        ).all()
    )
