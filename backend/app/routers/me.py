from fastapi import APIRouter, Depends

from app.auth import get_current_user
from app.schemas import MeResponse

router = APIRouter(prefix="/api", tags=["auth"])


@router.get("/me", response_model=MeResponse)
def get_me(user: dict = Depends(get_current_user)):
    """Return the authenticated user.

    Doubles as a cheap "is my token valid?" check for the frontend. The fields
    come from the access-token claims: `sub` is always present; profile fields
    (name/email/picture) only appear if the tenant adds them as custom claims —
    otherwise the app reads the profile from the ID token after login.
    """
    return MeResponse(
        sub=user["sub"],
        email=user.get("email"),
        name=user.get("name"),
        picture=user.get("picture"),
    )
