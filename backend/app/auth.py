"""Auth0 bearer-token verification.

The Flutter app logs in via Auth0 and sends the resulting access token on every
request as ``Authorization: Bearer <jwt>``. We verify that JWT locally against
Auth0's published signing keys (JWKS) — no secret, no round-trip to Auth0.

Auth is **mandatory** on every ``/api`` route: a valid token is always required.
If Auth0 is not configured (``AUTH0_DOMAIN`` / ``AUTH0_AUDIENCE`` unset) the
server cannot verify anyone, so requests fail with 503 rather than silently
running open. Tests bypass verification by overriding ``get_current_user``.
"""

from __future__ import annotations

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import Session, select

from app import credits
from app.config import settings
from app.db import get_session
from app.models import User

# auto_error=False: we craft the 401 ourselves (with a WWW-Authenticate header).
_bearer = HTTPBearer(auto_error=False)

# PyJWKClient fetches and caches Auth0's signing keys. Created lazily so the app
# still imports/boots when Auth0 is not configured.
_jwks_client: jwt.PyJWKClient | None = None


def _get_jwks_client() -> jwt.PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = jwt.PyJWKClient(settings.auth0_jwks_url)
    return _jwks_client


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    """Validate the bearer token and return its claims.

    A valid token is always required. Raises 503 if Auth0 isn't configured and
    401 if the token is missing/invalid. ``claims["sub"]`` is the stable
    per-user Auth0 id used as the owner key.
    """
    if not settings.auth_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication is not configured",
        )

    if credentials is None or not credentials.credentials:
        raise _unauthorized("Missing bearer token")

    token = credentials.credentials
    try:
        signing_key = _get_jwks_client().get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token,
            signing_key,
            algorithms=settings.auth0_algorithms,
            audience=settings.auth0_audience,
            issuer=settings.auth0_issuer,
        )
    except jwt.PyJWTError as exc:
        raise _unauthorized(f"Invalid token: {exc}")
    return claims


def current_auth0_id(
    user: dict = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> str:
    """The authenticated user's stable id (Auth0 ``sub``).

    Also registers the user in the ``users`` table on first sight (and refreshes
    their email/name from the token) so memberships can reference them.
    """
    sub = user["sub"]
    record = session.exec(select(User).where(User.auth0_id == sub)).first()
    if record is None:
        session.add(
            User(auth0_id=sub, email=user.get("email"), name=user.get("name"))
        )
        session.commit()
        # One-time welcome credits for a brand-new user.
        credits.grant_initial(session, sub)
    else:
        if record.credits == 0:
            # Existing account that may predate the credits system: grant the
            # welcome credits if the ledger shows they were never given (a
            # user who merely spent down to zero has an "initial" entry and
            # is NOT re-granted). Gated on a zero balance so the ledger check
            # doesn't run on every request.
            credits.ensure_initial_grant(session, sub)
        if user.get("email") and record.email != user.get("email"):
            record.email = user.get("email")
            record.name = user.get("name") or record.name
            session.add(record)
            session.commit()
    return sub
