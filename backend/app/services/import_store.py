"""In-memory staging buffer for roster import review.

The review session lives in process memory only — it is NOT a DB table. Imported
players are held here while the coach reviews/edits them; only `confirm` writes
to the real `player` table. Sessions are lost on restart (acceptable: a review is
short-lived and re-runnable from the photo). Process-local, so this assumes a
single backend worker.
"""

from dataclasses import dataclass, field
from threading import Lock
from typing import Optional


@dataclass
class MemItem:
    """One reviewed player (the editable imported values + classification)."""

    id: int
    name: str
    number: Optional[int] = None
    preferred_position: Optional[str] = None
    match_player_id: Optional[int] = None
    classification: str = "new"  # new | updated | duplicate | unchanged
    confidence: Optional[float] = None  # 0..1, for duplicate candidates
    rationale: Optional[str] = None
    deleted: bool = False


@dataclass
class MemSession:
    id: int
    owner_id: str
    team_id: int
    status: str = "pending"  # pending | confirmed | discarded
    items: list[MemItem] = field(default_factory=list)

    def item(self, item_id: int) -> Optional[MemItem]:
        return next((it for it in self.items if it.id == item_id), None)


class ImportStore:
    """Thread-safe-enough registry of in-memory import sessions."""

    def __init__(self) -> None:
        self._sessions: dict[int, MemSession] = {}
        self._next_session_id = 0
        self._next_item_id = 0
        self._lock = Lock()

    def new_item_id(self) -> int:
        with self._lock:
            self._next_item_id += 1
            return self._next_item_id

    def create(self, owner_id: str, team_id: int) -> MemSession:
        with self._lock:
            self._next_session_id += 1
            sess = MemSession(
                id=self._next_session_id, owner_id=owner_id, team_id=team_id
            )
            self._sessions[sess.id] = sess
            return sess

    def get(self, session_id: int) -> Optional[MemSession]:
        return self._sessions.get(session_id)

    def pending_for_team(self, owner_id: str, team_id: int) -> list[MemSession]:
        return [
            s
            for s in self._sessions.values()
            if s.owner_id == owner_id
            and s.team_id == team_id
            and s.status == "pending"
        ]

    def clear(self) -> None:
        """Reset everything (used by tests)."""
        with self._lock:
            self._sessions.clear()
            self._next_session_id = 0
            self._next_item_id = 0


# Module-level singleton.
store = ImportStore()
