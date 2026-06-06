from app.agents import build_agent
from app.schemas import AdjustResult, LineupResult, PlayerOut

GENERATE_PROMPT = (
    "You are a football tactician. Given the available players and the "
    "opponent, pick a sensible formation (e.g. 4-3-3, 4-2-3-1, 3-5-2) and "
    "assign each player to a position. Use only the players provided. "
    "Briefly explain the tactical reason."
)

ADJUST_PROMPT = (
    "You are a football coach making in-match adjustments. Given the current "
    "lineup and a note about what is happening on the pitch (fatigue, a flank "
    "being overrun, etc.), suggest substitutions and/or position changes using "
    "only the players in the lineup. Keep it minimal and explain why."
)


async def generate_lineup(
    players: list[PlayerOut], opponent: str, strength: str | None
) -> LineupResult:
    agent = build_agent("lineup_generate", LineupResult, GENERATE_PROMPT)
    roster = ", ".join(
        f"{p.name}"
        + (f" (#{p.number})" if p.number else "")
        + (f" [{p.preferred_position}]" if p.preferred_position else "")
        for p in players
    )
    prompt = (
        f"Available players: {roster}.\n"
        f"Opponent: {opponent}.\n"
        f"Opponent strength: {strength or 'unknown'}.\n"
        "Produce the formation and starting lineup."
    )
    result = await agent.run(prompt)
    return result.output


async def adjust_lineup(current_lineup: LineupResult, note: str) -> AdjustResult:
    agent = build_agent("lineup_adjust", AdjustResult, ADJUST_PROMPT)
    current = ", ".join(f"{s.player} @ {s.position}" for s in current_lineup.lineup)
    prompt = (
        f"Current formation: {current_lineup.formation}.\n"
        f"Current lineup: {current}.\n"
        f"In-match note: {note}.\n"
        "Suggest adjustments."
    )
    result = await agent.run(prompt)
    return result.output
