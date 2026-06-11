"""Request/response models — the API contract shared with the frontend.

Kept separate from the SQLModel tables so the wire format is stable even if
storage changes. Agent result types live here too (reused as PydanticAI
`result_type`s) so the LLM output is validated against the same shapes.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ---- Auth ----
class MeResponse(BaseModel):
    """The current authenticated user (from the stored `users` row, falling back
    to Auth0 access-token claims)."""

    sub: str
    email: Optional[str] = None
    name: Optional[str] = None
    picture: Optional[str] = None


class MeUpdate(BaseModel):
    """Update the current user's profile (name/email synced from Auth0 on login,
    or edited by the user)."""

    name: Optional[str] = None
    email: Optional[str] = None


# ---- Players / teams ----
class PlayerOut(BaseModel):
    name: str
    number: Optional[int] = None
    preferred_position: Optional[str] = None


class RosterResult(BaseModel):
    """Agent 1 (roster extractor) output."""

    players: list[PlayerOut]


class RosterResponse(BaseModel):
    team_id: int
    players: list[PlayerOut]


class Absence(BaseModel):
    """An unavailability period (injury or vacation). `from`/`to` are inclusive
    YYYY-MM-DD dates."""

    model_config = ConfigDict(populate_by_name=True)

    kind: str  # "injury" | "vacation"
    from_: str = Field(alias="from")
    to: str
    note: Optional[str] = None


class TeamPlayer(BaseModel):
    """A roster player as returned to the app — includes the DB id so the client
    can act on individual players (e.g. delete)."""

    id: int
    name: str
    nickname: Optional[str] = None
    number: Optional[int] = None
    preferred_position: Optional[str] = None
    positions: list[str] = []
    absences: list[Absence] = []


class TeamResponse(BaseModel):
    id: int
    name: str
    players: list[TeamPlayer]


class PlayerDetail(BaseModel):
    """Full editable profile for one player (player detail screen)."""

    id: int
    name: str
    nickname: Optional[str] = None
    number: Optional[int] = None
    preferred_position: Optional[str] = None
    positions: list[str] = []
    preferred_foot: Optional[str] = None  # "left" | "right" | "both"
    height_cm: Optional[int] = None
    traits: list[str] = []
    description: Optional[str] = None
    absences: list[Absence] = []


class PlayerUpdate(BaseModel):
    """Manual edit of a player profile — every field optional (PATCH)."""

    name: Optional[str] = None
    nickname: Optional[str] = None
    number: Optional[int] = None
    preferred_position: Optional[str] = None
    positions: Optional[list[str]] = None
    preferred_foot: Optional[str] = None
    height_cm: Optional[int] = None
    traits: Optional[list[str]] = None
    description: Optional[str] = None
    absences: Optional[list[Absence]] = None


class DescribeRequest(BaseModel):
    text: str


class PlayerProfileResult(BaseModel):
    """Agent output: a player's COMPLETE profile, extracted/merged from a
    spoken or typed description. Empty/None fields mean 'no information'."""

    nickname: Optional[str] = None
    number: Optional[int] = None
    positions: list[str] = []
    preferred_foot: Optional[str] = None
    height_cm: Optional[int] = None
    traits: list[str] = []
    description: Optional[str] = None


class TeamCreate(BaseModel):
    name: str


class TeamSummary(BaseModel):
    """A team in the user's team list (without the roster). `join_code` is the
    code other users enter to join this (shared) team — it is only returned to
    the team's owner (null for other members). `is_owner` marks whether the
    caller created (and may delete / re-code) the team."""

    id: int
    name: str
    join_code: Optional[str] = None
    is_owner: bool = False


class JoinRequest(BaseModel):
    code: str


class CreditsBalance(BaseModel):
    """The current user's credit balance (shown in the app header)."""

    balance: int


class CreditTransactionOut(BaseModel):
    """One entry in the credit ledger (credit history screen)."""

    id: int
    amount: int  # + grant, - spend
    balance_after: int
    kind: str  # "initial" | "text" | "image" | "voice"
    description: Optional[str] = None
    created_at: datetime


class TeamMember(BaseModel):
    """A user who belongs to a team (shown in the Profile team list)."""

    auth0_id: str
    name: Optional[str] = None
    email: Optional[str] = None


# ---- Roster import review ----
class FieldChange(BaseModel):
    """A single changed field on an "updated" import item (for before/after)."""

    field: str  # "name" | "number" | "preferred_position"
    before: Optional[str] = None
    after: Optional[str] = None


class ImportItemOut(BaseModel):
    id: int
    name: str
    number: Optional[int] = None
    preferred_position: Optional[str] = None
    classification: str  # "new" | "updated" | "duplicate" | "unchanged"
    confidence: Optional[float] = None  # 0..1, set for duplicate candidates
    rationale: Optional[str] = None
    deleted: bool = False
    # The existing player a non-"new" item maps to (for merge / before-after).
    match: Optional[PlayerOut] = None
    match_player_id: Optional[int] = None
    changes: list[FieldChange] = []


class ImportReviewResponse(BaseModel):
    """The full review, grouped into the sections the UI renders."""

    session_id: int
    team_id: int
    status: str
    new_players: list[ImportItemOut] = []
    updated_players: list[ImportItemOut] = []
    duplicate_candidates: list[ImportItemOut] = []
    unchanged_players: list[ImportItemOut] = []
    # Optional short message from an AI command (e.g. "Merged Li Gang into 李刚").
    reply: Optional[str] = None


class ImportItemEdit(BaseModel):
    """Manual edit of one item — only updates the temporary session."""

    name: Optional[str] = None
    number: Optional[int] = None
    preferred_position: Optional[str] = None


class MergeRequest(BaseModel):
    """Resolve a duplicate by linking it to an existing player, or fold one
    imported row into another. Exactly one target should be provided."""

    target_player_id: Optional[int] = None
    target_item_id: Optional[int] = None


class CommandRequest(BaseModel):
    text: str


class ConfirmResponse(BaseModel):
    created: int
    updated: int
    skipped: int


# Agent: roster matcher (cross-language / spelling-variant duplicate finder)
class MatchCandidate(BaseModel):
    imported_index: int
    matched_player_id: Optional[int] = None
    confidence: float = 0.0  # 0..1
    rationale: Optional[str] = None


class MatchResult(BaseModel):
    """Roster-matcher agent output."""

    matches: list[MatchCandidate] = []


# Agent: natural-language import command parser
class ImportAction(BaseModel):
    type: str  # "edit" | "delete" | "merge"
    item_id: int
    name: Optional[str] = None
    number: Optional[int] = None
    preferred_position: Optional[str] = None
    target_item_id: Optional[int] = None
    target_player_id: Optional[int] = None


class CommandResult(BaseModel):
    """Import command-parser agent output."""

    actions: list[ImportAction] = []
    reply: Optional[str] = None


# ---- Matches ----
class MatchInput(BaseModel):
    team_id: int
    opponent: str
    is_home: bool = True
    location: str = ""
    pitch: Optional[str] = None
    address: Optional[str] = None
    date: str
    kickoff_time: Optional[str] = None
    notes: Optional[str] = None
    strength: Optional[str] = None


class MatchResponse(BaseModel):
    id: int
    team_id: int
    opponent: str
    is_home: bool = True
    location: str = ""
    pitch: Optional[str] = None
    address: Optional[str] = None
    date: str
    kickoff_time: Optional[str] = None
    notes: Optional[str] = None
    strength: Optional[str] = None
    # Coach's per-match availability override (None = derive from absences).
    unavailable_player_ids: Optional[list[int]] = None


class MatchUpdate(BaseModel):
    """Edit an existing match — every field optional (PATCH)."""

    opponent: Optional[str] = None
    is_home: Optional[bool] = None
    location: Optional[str] = None
    pitch: Optional[str] = None
    address: Optional[str] = None
    date: Optional[str] = None
    kickoff_time: Optional[str] = None
    notes: Optional[str] = None
    strength: Optional[str] = None
    unavailable_player_ids: Optional[list[int]] = None


class MatchDraft(BaseModel):
    """One match parsed from a photo/voice, for the create-review step."""

    opponent: str = ""
    is_home: Optional[bool] = None  # our team at home? (null → unknown)
    date: Optional[str] = None  # YYYY-MM-DD when determinable
    kickoff_time: Optional[str] = None  # "HH:MM"
    pitch: Optional[str] = None
    address: Optional[str] = None
    strength: Optional[str] = None  # "strong" | "weak" | None
    notes: Optional[str] = None


class MatchExtractResult(BaseModel):
    """Match extractor agent output (a fixtures photo / spoken schedule)."""

    matches: list[MatchDraft] = []


# ---- Lineup (Agent 2, generate) ----
class LineupSlot(BaseModel):
    player: str
    position: str
    # The player's nickname (attached server-side from the roster, not by the
    # agent) so the pitch can label dots with what teammates call them.
    nickname: Optional[str] = None
    # Custom pitch coordinates in percent (0-100), set when the coach drags a
    # player to a free spot. Null = the app lays out by position code.
    x: Optional[float] = None
    y: Optional[float] = None


class LineupRequest(BaseModel):
    strength: Optional[str] = None
    # Players on the pitch including the GK (5 / 7 / 11). Default 11.
    team_size: Optional[int] = None
    # Requested formation (e.g. "4-3-3", "2-3-1"); None lets the AI pick.
    formation: Optional[str] = None
    # Free-text coach instructions (typed or transcribed from voice).
    instructions: Optional[str] = None
    # ISO 639-1 code for the AI reasoning text; None → infer from squad/venue.
    language: Optional[str] = None


class LineupEdit(BaseModel):
    """Manual lineup edit from the pitch screen (drag & drop): the full
    starters + bench as the coach arranged them. No credits — no LLM call."""

    formation: Optional[str] = None
    lineup: list[LineupSlot]
    subs: list[LineupSlot] = []


class LineupResult(BaseModel):
    """Agent 2 (lineup generator) output."""

    formation: str
    lineup: list[LineupSlot]
    # Remaining players (bench), in recommended substitution order.
    subs: list[LineupSlot] = []
    reason: str


# ---- Notes / in-match adjustments (Agent 2, adjust) ----
class NoteInput(BaseModel):
    kind: str = "text"  # "text" | "voice"
    content: str


class Substitution(BaseModel):
    # JSON key is "in" (reserved word in Python), so the field is "in_".
    model_config = ConfigDict(populate_by_name=True)

    out: str
    in_: str = Field(alias="in")


class PositionChange(BaseModel):
    player: str
    to: str


class AdjustResult(BaseModel):
    """Agent 2 (adjust mode) output."""

    # Whether the coach needs an answer on screen. False for pure event logs
    # (goal, card, sub made…) — the note is registered silently.
    respond: bool = True
    substitutions: list[Substitution] = []
    position_changes: list[PositionChange] = []
    reason: str


class NoteResponse(BaseModel):
    note_id: int
    suggestion: AdjustResult


class NoteOut(BaseModel):
    id: int
    kind: str
    content: str
    ai_response: dict


class VoiceNoteResponse(BaseModel):
    note_id: int
    transcription: str  # the text the audio was transcribed to
    suggestion: AdjustResult


# ---- Summary (Agent 3) ----
class PlayerPerformance(BaseModel):
    player: str
    rating: str
    comment: str


class SummaryResult(BaseModel):
    """Agent 3 (match analyst) output."""

    summary: str
    player_performance: list[PlayerPerformance]
    improvements: list[str]
