"""Credit balance + ledger endpoints (read-only).

Spending happens inside the LLM endpoints via ``app.credits``; this router only
exposes the current balance (for the header) and the full transaction history.
"""

from fastapi import APIRouter, Depends
from sqlmodel import Session

from app import credits
from app.auth import current_auth0_id
from app.db import get_session
from app.schemas import CreditsBalance, CreditTransactionOut

router = APIRouter(prefix="/api/credits", tags=["credits"])


@router.get("", response_model=CreditsBalance)
def get_balance(
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    return CreditsBalance(balance=credits.balance(session, auth0_id))


@router.get("/transactions", response_model=list[CreditTransactionOut])
def list_transactions(
    session: Session = Depends(get_session),
    auth0_id: str = Depends(current_auth0_id),
):
    return [
        CreditTransactionOut(
            id=t.id,
            amount=t.amount,
            balance_after=t.balance_after,
            kind=t.kind,
            description=t.description,
            created_at=t.created_at,
        )
        for t in credits.transactions(session, auth0_id)
    ]
