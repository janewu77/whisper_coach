import secrets
import string
from datetime import datetime, timezone
from typing import Optional

from sqlmodel import JSON, Column, Field, SQLModel


def _now() -> datetime:
    return datetime.now(timezone.utc)


# Unambiguous alphabet for team join codes (no O/0/I/1).
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _join_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(8))


class User(SQLModel, table=True):
    """A registered user. Surrogate ``id`` PK; ``auth0_id`` (the Auth0 ``sub``)
    is the unique business key. Created on first request."""

    __tablename__ = "users"

    id: Optional[int] = Field(default=None, primary_key=True)
    # unique=True (not index=True) → a UNIQUE *constraint*, which Postgres
    # requires for user_team.auth0_id to reference it as a foreign key.
    auth0_id: str = Field(unique=True)
    email: Optional[str] = None
    name: Optional[str] = None
    created_at: datetime = Field(default_factory=_now)


class Team(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    # Short code another user enters to join (share a team across users).
    join_code: str = Field(default_factory=_join_code, index=True, unique=True)
    created_at: datetime = Field(default_factory=_now)


class UserTeam(SQLModel, table=True):
    """Membership: which users belong to which teams (many-to-many). Access to a
    team and its matches/roster is granted to every member (no roles).
    ``auth0_id`` is the Auth0 ``sub`` (FK to users.auth0_id)."""

    __tablename__ = "user_team"

    auth0_id: str = Field(foreign_key="users.auth0_id", primary_key=True)
    team_id: int = Field(foreign_key="team.id", primary_key=True)
    created_at: datetime = Field(default_factory=_now)


class Player(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    team_id: int = Field(foreign_key="team.id", index=True)
    name: str
    number: Optional[int] = None
    preferred_position: Optional[str] = None
    # Extended profile (set via the player detail screen / voice profiling).
    positions: list = Field(default_factory=list, sa_column=Column(JSON))  # e.g. ["ST","RW"]
    preferred_foot: Optional[str] = None  # "left" | "right" | "both"
    height_cm: Optional[int] = None
    traits: list = Field(default_factory=list, sa_column=Column(JSON))  # ["strong", ...]
    description: Optional[str] = None
    # Unavailability periods: [{"kind": "injury"|"vacation", "from": "YYYY-MM-DD",
    # "to": "YYYY-MM-DD", "note": str?}]. Availability is derived by comparing the
    # ranges to a reference date (today / next match) on the client.
    absences: list = Field(default_factory=list, sa_column=Column(JSON))


class Match(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    # Access is via the team's membership (UserTeam) — no per-match owner.
    team_id: int = Field(foreign_key="team.id", index=True)
    opponent: str
    # Whether OUR team plays at home. The home team is listed first in the UI.
    is_home: bool = True
    location: str = ""  # legacy free-text venue (kept for old rows); use `pitch`
    pitch: Optional[str] = None  # ground / pitch name
    date: str
    kickoff_time: Optional[str] = None  # "HH:MM"
    notes: Optional[str] = None
    strength: Optional[str] = None  # "strong" | "weak" | None
    # Last generated post-match summary (SummaryResult shape); null until made.
    summary: Optional[dict] = Field(default=None, sa_column=Column(JSON))
    created_at: datetime = Field(default_factory=_now)


class Lineup(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    match_id: int = Field(foreign_key="match.id", index=True)
    formation: str
    slots: list = Field(sa_column=Column(JSON))  # [{"player": str, "position": str}]
    reason: str
    created_at: datetime = Field(default_factory=_now)


class Note(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    match_id: int = Field(foreign_key="match.id", index=True)
    kind: str  # "text" | "voice"
    content: str
    ai_response: dict = Field(default_factory=dict, sa_column=Column(JSON))
    created_at: datetime = Field(default_factory=_now)


# NOTE: the roster import-review session is intentionally NOT a DB table. It is a
# short-lived, in-memory staging buffer (see app/services/import_store.py) so
# OCR/AI output never persists until the coach confirms. Only `confirm` writes to
# the `player` table above.
