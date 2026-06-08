"""Roster-import review logic: classify imported players, recompute on edits,
and serialize the grouped review the UI renders.

Operates on the in-memory MemSession/MemItem (see import_store.py) — the live
`player` table is only read here (for comparison); it is written only on confirm.

Classification (per imported player):
  - exact name match to an existing player  -> "unchanged" (fields equal) or
    "updated" (some field differs)
  - cross-language / spelling match found by the AI matcher (name written
    differently) -> "duplicate" candidate, with a confidence score
  - no match -> "new"
"""

import re
from typing import Callable

from app.agents.matcher import match_roster
from app.models import Player
from app.schemas import (
    FieldChange,
    ImportItemOut,
    ImportReviewResponse,
    PlayerOut,
)
from app.services.import_store import MemItem, MemSession

# Below this AI confidence we don't treat a fuzzy hit as a duplicate at all.
DUPLICATE_MIN_CONFIDENCE = 0.5


def normalize(name: str) -> str:
    """Case/space-insensitive key for exact-name matching (CJK compares as-is)."""
    return re.sub(r"\s+", " ", (name or "").strip()).casefold()


def _player_out(p: Player) -> PlayerOut:
    return PlayerOut(
        name=p.name, number=p.number, preferred_position=p.preferred_position
    )


def _s(v: object) -> str | None:
    return None if v is None else str(v)


def diff_fields(item: MemItem, p: Player) -> list[FieldChange]:
    """Field-level before/after between an item and the existing player it maps
    to. `before` = existing value, `after` = imported value."""
    changes: list[FieldChange] = []
    if item.name != p.name:
        changes.append(FieldChange(field="name", before=p.name, after=item.name))
    if item.number != p.number:
        changes.append(
            FieldChange(field="number", before=_s(p.number), after=_s(item.number))
        )
    if (item.preferred_position or None) != (p.preferred_position or None):
        changes.append(
            FieldChange(
                field="preferred_position",
                before=p.preferred_position,
                after=item.preferred_position,
            )
        )
    return changes


def recompute_against_match(item: MemItem, match: Player | None) -> None:
    """Set classification for a resolved (non-duplicate) item: 'new' when there
    is no match, else 'unchanged'/'updated' by field diff. Clears confidence."""
    item.confidence = None
    if match is None:
        item.match_player_id = None
        item.classification = "new"
        return
    item.match_player_id = match.id
    item.classification = "unchanged" if not diff_fields(item, match) else "updated"


async def classify_imported(
    imported: list[PlayerOut],
    existing: list[Player],
    new_id: Callable[[], int],
) -> list[MemItem]:
    """Build classified MemItems for a fresh import against the existing roster.
    Exact-name matches are resolved deterministically; leftovers go to the AI
    matcher to surface cross-language duplicate candidates. `new_id` allocates
    item ids."""
    by_norm: dict[str, Player] = {}
    for p in existing:
        by_norm.setdefault(normalize(p.name), p)

    items: list[MemItem] = []
    leftover: list[tuple[int, PlayerOut]] = []  # (item_index, player)
    consumed: set[int] = set()  # existing player ids already matched exactly

    for idx, ip in enumerate(imported):
        item = MemItem(
            id=new_id(),
            name=ip.name,
            number=ip.number,
            preferred_position=ip.preferred_position,
        )
        match = by_norm.get(normalize(ip.name))
        if match is not None and match.id not in consumed:
            consumed.add(match.id)
            recompute_against_match(item, match)
        else:
            item.classification = "new"
            leftover.append((idx, ip))
        items.append(item)

    # AI pass: only leftovers vs still-unmatched existing players.
    remaining_existing = [
        (p.id, _player_out(p)) for p in existing if p.id not in consumed
    ]
    if leftover and remaining_existing:
        result = await match_roster(leftover, remaining_existing)
        existing_by_id = {p.id: p for p in existing}
        for cand in result.matches:
            if cand.matched_player_id is None:
                continue
            if cand.confidence < DUPLICATE_MIN_CONFIDENCE:
                continue
            if 0 <= cand.imported_index < len(items):
                target = existing_by_id.get(cand.matched_player_id)
                if target is None:
                    continue
                item = items[cand.imported_index]
                item.classification = "duplicate"
                item.match_player_id = cand.matched_player_id
                item.confidence = max(0.0, min(1.0, cand.confidence))
                item.rationale = cand.rationale

    return items


def serialize_item(
    item: MemItem, existing_by_id: dict[int, Player]
) -> ImportItemOut:
    match = (
        existing_by_id.get(item.match_player_id)
        if item.match_player_id is not None
        else None
    )
    return ImportItemOut(
        id=item.id,
        name=item.name,
        number=item.number,
        preferred_position=item.preferred_position,
        classification=item.classification,
        confidence=item.confidence,
        rationale=item.rationale,
        deleted=item.deleted,
        match=_player_out(match) if match else None,
        match_player_id=item.match_player_id,
        changes=diff_fields(item, match) if match else [],
    )


def build_review(
    session: MemSession,
    existing_by_id: dict[int, Player],
    reply: str | None = None,
) -> ImportReviewResponse:
    """Group non-deleted items into the four review sections."""
    out = ImportReviewResponse(
        session_id=session.id,
        team_id=session.team_id,
        status=session.status,
        reply=reply,
    )
    buckets = {
        "new": out.new_players,
        "updated": out.updated_players,
        "duplicate": out.duplicate_candidates,
        "unchanged": out.unchanged_players,
    }
    for item in session.items:
        if item.deleted:
            continue
        bucket = buckets.get(item.classification)
        if bucket is not None:
            bucket.append(serialize_item(item, existing_by_id))
    return out
