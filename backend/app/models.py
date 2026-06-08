from datetime import datetime, timezone
from typing import Optional

from sqlmodel import JSON, Column, Field, SQLModel


def _now() -> datetime:
    return datetime.now(timezone.utc)


class Team(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    # Auth0 user id ("sub") of the owner. Every team is scoped to one user.
    owner_id: str = Field(index=True)
    name: str
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


class Match(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    # Denormalized owner ("sub") so matches can be listed/guarded without a join;
    # set from the authenticated user (and validated against the team) at creation.
    owner_id: str = Field(index=True)
    team_id: int = Field(foreign_key="team.id", index=True)
    opponent: str
    location: str
    date: str
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
