"""Request/response models — the API contract shared with the frontend.

Kept separate from the SQLModel tables so the wire format is stable even if
storage changes. Agent result types live here too (reused as PydanticAI
`result_type`s) so the LLM output is validated against the same shapes.
"""

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ---- Auth ----
class MeResponse(BaseModel):
    """The current authenticated user (from the Auth0 access-token claims)."""

    sub: str
    email: Optional[str] = None
    name: Optional[str] = None
    picture: Optional[str] = None


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


class TeamResponse(BaseModel):
    id: int
    name: str
    players: list[PlayerOut]


class TeamCreate(BaseModel):
    name: str


class TeamSummary(BaseModel):
    """A team in the user's team list (without the roster)."""

    id: int
    name: str


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
    location: str
    date: str
    notes: Optional[str] = None
    strength: Optional[str] = None


class MatchResponse(BaseModel):
    id: int
    team_id: int
    opponent: str
    location: str
    date: str
    notes: Optional[str] = None
    strength: Optional[str] = None


# ---- Lineup (Agent 2, generate) ----
class LineupSlot(BaseModel):
    player: str
    position: str


class LineupRequest(BaseModel):
    strength: Optional[str] = None


class LineupResult(BaseModel):
    """Agent 2 (lineup generator) output."""

    formation: str
    lineup: list[LineupSlot]
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
