"""Roster matcher — finds duplicate candidates across naming differences.

Used by the import-review flow for imported players that did NOT match an
existing player by exact name. The LLM spots the same person written
differently: translations (Li Gang ↔ 李刚), pinyin/transliterations, nicknames,
or spelling variations, with a confidence score the coach reviews before merging.
"""

from app.agents import build_agent
from app.schemas import MatchResult, PlayerOut

SYSTEM_PROMPT = (
    "You match newly imported football players against an existing team roster "
    "to find DUPLICATES that are written differently: translations (e.g. "
    "'Li Gang' <-> '李刚'), pinyin/transliterations, nicknames, or spelling "
    "variations of the same person. Match each imported player to AT MOST one "
    "existing player, by `imported_index` and `matched_player_id`. Give a "
    "`confidence` from 0 to 1 and a short `rationale`. Do NOT match players who "
    "merely share a position or jersey number. If an imported player has no "
    "plausible existing match, leave it out."
)


def _fmt_player(p: PlayerOut) -> str:
    extra = []
    if p.number is not None:
        extra.append(f"#{p.number}")
    if p.preferred_position:
        extra.append(p.preferred_position)
    return p.name + (f" ({', '.join(extra)})" if extra else "")


async def match_roster(
    imported: list[tuple[int, PlayerOut]],
    existing: list[tuple[int, PlayerOut]],
) -> MatchResult:
    """Find duplicate candidates among `imported` (index, player) against the
    `existing` (player_id, player) roster. Returns only plausible matches."""
    if not imported or not existing:
        return MatchResult(matches=[])

    agent = build_agent("roster_matcher", MatchResult, SYSTEM_PROMPT)
    imported_lines = "\n".join(
        f"  imported_index={idx}: {_fmt_player(p)}" for idx, p in imported
    )
    existing_lines = "\n".join(
        f"  matched_player_id={pid}: {_fmt_player(p)}" for pid, p in existing
    )
    prompt = (
        "Imported players to match:\n"
        f"{imported_lines}\n\n"
        "Existing roster:\n"
        f"{existing_lines}\n\n"
        "Return only the imported players that are likely the same person as an "
        "existing one (written differently), with confidence and rationale."
    )
    result = await agent.run(prompt)
    return result.output
