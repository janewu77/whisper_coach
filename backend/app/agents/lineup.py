from app.agents import build_agent
from app.schemas import AdjustResult, LineupResult, PlayerOut

GENERATE_PROMPT = (
    "You are a football tactician. Given the available players and the "
    "opponent, pick a sensible formation and assign players to positions. "
    "The team size (including the goalkeeper) may be 11, 7 or 5 (small-sided "
    "football); formations are written without the GK (e.g. 4-3-3 for "
    "11-a-side, 2-3-1 for 7-a-side, 1-2-1 for 5-a-side). If the coach "
    "requests a specific formation, use exactly that one. Put exactly the "
    "team-size number of players into `lineup` (the starters) and EVERY "
    "remaining player into `subs`, in recommended substitution order, each "
    "with the position they would cover. Use only the players provided and "
    "follow any coach instructions. Briefly explain the tactical reason."
)

ADJUST_PROMPT = (
    "You are a football coach making in-match adjustments. Given the current "
    "lineup and a note about what is happening on the pitch (fatigue, a flank "
    "being overrun, etc.), suggest substitutions and/or position changes using "
    "only the players in the lineup. Keep it minimal and explain why."
)


async def generate_lineup(
    players: list[PlayerOut],
    opponent: str,
    strength: str | None,
    team_size: int | None = None,
    formation: str | None = None,
    instructions: str | None = None,
) -> LineupResult:
    agent = build_agent("lineup_generate", LineupResult, GENERATE_PROMPT)
    roster = ", ".join(
        f"{p.name}"
        + (f" (#{p.number})" if p.number else "")
        + (f" [{p.preferred_position}]" if p.preferred_position else "")
        for p in players
    )
    size = team_size or 11
    prompt = (
        f"Available players: {roster}.\n"
        f"Opponent: {opponent}.\n"
        f"Opponent strength: {strength or 'unknown'}.\n"
        f"Team size: {size}-a-side — exactly {size} starters incl. GK.\n"
        + (f"Requested formation: {formation} — use exactly this.\n"
           if formation else "")
        + (f"Coach instructions: {instructions}\n" if instructions else "")
        + "Produce the formation, the starting lineup, and the subs (bench)."
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
