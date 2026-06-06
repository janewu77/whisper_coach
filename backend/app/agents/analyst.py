from app.agents import build_agent
from app.schemas import LineupResult, SummaryResult

SYSTEM_PROMPT = (
    "You are a football analyst. Given the starting formation and the notes / "
    "adjustments made during a match, write a concise post-match summary, rate "
    "the players mentioned, and list concrete improvement suggestions."
)


async def summarize_match(
    lineup: LineupResult | None, notes: list[str]
) -> SummaryResult:
    agent = build_agent("analyst", SummaryResult, SYSTEM_PROMPT)
    formation = lineup.formation if lineup else "unknown"
    starters = (
        ", ".join(f"{s.player} @ {s.position}" for s in lineup.lineup)
        if lineup
        else "unknown"
    )
    notes_text = "\n".join(f"- {n}" for n in notes) if notes else "(no notes)"
    prompt = (
        f"Formation: {formation}.\n"
        f"Lineup: {starters}.\n"
        f"In-match notes and adjustments:\n{notes_text}\n"
        "Write the post-match summary."
    )
    result = await agent.run(prompt)
    return result.output
