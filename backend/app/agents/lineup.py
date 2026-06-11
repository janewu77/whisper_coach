from app.agents import build_agent
from app.schemas import AdjustResult, LineupResult, LineupSlot, PlayerOut

# Position-code bands (defence → attack), used to verify and repair a
# requested formation. Mirrors the pitch layout in the app.
_DEF = {"LB", "CB", "RB", "LWB", "RWB", "SW"}
_MID_DEF = {"CDM", "DM"}
_MID = {"CM", "LM", "RM"}
_MID_ATT = {"CAM", "AM"}
_ATT = {"LW", "RW", "ST", "CF", "FW"}


def _rows(formation: str) -> list[int]:
    try:
        return [int(p) for p in formation.split("-") if p.strip().isdigit()]
    except ValueError:
        return []


def _formation_ok(
    result: LineupResult, formation: str | None, team_size: int | None
) -> bool:
    """Does the result honor the requested formation (string AND shape)?"""
    if not formation:
        return True
    rows = _rows(formation)
    size = team_size or 11
    if not rows or sum(rows) != size - 1:
        return True  # malformed request — nothing to enforce
    if result.formation.replace(" ", "") != formation.replace(" ", ""):
        return False
    if len(result.lineup) != size:
        return False
    poss = [s.position.strip().upper() for s in result.lineup]
    if poss.count("GK") != 1:
        return False
    n_def = sum(1 for p in poss if p in _DEF)
    n_att = sum(1 for p in poss if p in _ATT)
    # Midfield bands are interchangeable; defence and attack must match.
    return n_def == rows[0] and n_att == rows[-1]


def _row_codes(rows: list[int]) -> list[str]:
    """Position codes for each outfield row of a formation, defence → attack."""
    codes: list[str] = []
    middle = rows[1:-1] if len(rows) > 2 else []
    mid_bases = {0: [], 1: ["CM"], 2: ["CM", "CAM"]}.get(
        len(middle), ["CDM", "CM", "CAM"] + ["CAM"] * (len(middle) - 3)
    )
    for i, n in enumerate(rows):
        if i == 0:
            codes += {
                1: ["CB"],
                2: ["CB", "CB"],
                3: ["CB", "CB", "CB"],
                4: ["LB", "CB", "CB", "RB"],
                5: ["LWB", "CB", "CB", "CB", "RWB"],
            }.get(n, ["CB"] * n)
        elif i == len(rows) - 1:
            codes += {
                1: ["ST"],
                2: ["ST", "ST"],
                3: ["LW", "ST", "RW"],
                4: ["LW", "ST", "ST", "RW"],
            }.get(n, ["ST"] * n)
        else:
            codes += [mid_bases[i - 1]] * n
    return codes


def _force_formation(
    result: LineupResult, formation: str, team_size: int | None
) -> LineupResult:
    """Deterministic last resort: relabel the starters' positions so the squad
    matches the requested formation exactly (keeps the agent's player choice,
    ordered defence → attack)."""
    rows = _rows(formation)
    size = team_size or 11
    if not rows or sum(rows) != size - 1:
        return result
    slots = list(result.lineup)
    gk = next(
        (s for s in slots if s.position.strip().upper() == "GK"), slots[0]
    )
    rest = [s for s in slots if s is not gk]
    if len(rest) != size - 1:
        return result  # wrong starter count — can't repair by relabelling

    def band(s: LineupSlot) -> int:
        p = s.position.strip().upper()
        if p in _DEF:
            return 0
        if p in _MID_DEF:
            return 1
        if p in _MID:
            return 2
        if p in _MID_ATT:
            return 3
        if p in _ATT:
            return 4
        return 2

    rest.sort(key=band)  # stable: keeps the agent's order within a band
    codes = _row_codes(rows)
    result.formation = formation
    result.lineup = [
        LineupSlot(player=gk.player, position="GK", nickname=gk.nickname)
    ] + [
        LineupSlot(player=s.player, position=c, nickname=s.nickname)
        for s, c in zip(rest, codes)
    ]
    return result

GENERATE_PROMPT = (
    "You are a football tactician. Given the available players and the "
    "opponent, pick a sensible formation and assign players to positions. "
    "The team size (including the goalkeeper) may be 11, 7 or 5 (small-sided "
    "football); formations are written without the GK (e.g. 4-3-3 for "
    "11-a-side, 2-3-1 for 7-a-side, 1-2-1 for 5-a-side). If the coach "
    "requests a specific formation, use exactly that one. Put exactly the "
    "team-size number of players into `lineup` (the starters) and EVERY "
    "remaining player into `subs`, in recommended substitution order, each "
    "with the position they would cover. Always write positions as standard "
    "short codes (GK, CB, LB, RB, LWB, RWB, CDM, CM, CAM, LM, RM, LW, RW, "
    "ST) — never spelled out. Use only the players provided and follow any "
    "coach instructions. Briefly explain the tactical reason."
)

ADJUST_PROMPT = (
    "You are a football coach's in-match assistant. The coach sends short "
    "notes during the game. FIRST decide whether the note needs an answer:\n"
    "- If it is just logging an event (a goal, a card, a substitution made, "
    "kickoff/half-time, the score, etc.) and asks for nothing, set "
    "respond=false, leave substitutions/position_changes empty, and put a "
    "very short acknowledgement in reason (e.g. 'Noted: 1-0.'). Say NOTHING "
    "else — the note is only being registered.\n"
    "- If the coach asks a question, wants advice, or describes a problem "
    "(fatigue, a flank overrun, losing midfield…), set respond=true and "
    "suggest minimal substitutions and/or position changes using only the "
    "players in the lineup, and explain why in reason."
)


async def generate_lineup(
    players: list[PlayerOut],
    opponent: str,
    strength: str | None,
    team_size: int | None = None,
    formation: str | None = None,
    instructions: str | None = None,
    language: str | None = None,
    venue: str | None = None,
) -> LineupResult:
    agent = build_agent("lineup_generate", LineupResult, GENERATE_PROMPT)
    roster = ", ".join(
        f"{p.name}"
        + (f" (#{p.number})" if p.number else "")
        + (f" [{p.preferred_position}]" if p.preferred_position else "")
        for p in players
    )
    size = team_size or 11
    # The coach's set language wins; otherwise infer from the squad/venue.
    reason_lang = (
        f"Write `reason` in the language with ISO 639-1 code '{language}'.\n"
        if language
        else (
            "Write `reason` in the coach's likely language — infer it from "
            "the player names and the venue; if unclear, use English.\n"
        )
    )
    prompt = (
        f"Available players: {roster}.\n"
        f"Opponent: {opponent}.\n"
        f"Opponent strength: {strength or 'unknown'}.\n"
        + (f"Venue: {venue}.\n" if venue else "")
        + f"Team size: {size}-a-side — exactly {size} starters incl. GK.\n"
        + (f"Requested formation: {formation} — use exactly this.\n"
           if formation else "")
        + (f"Coach instructions: {instructions}\n" if instructions else "")
        + reason_lang
        + "Produce the formation, the starting lineup, and the subs (bench)."
    )
    result = (await agent.run(prompt)).output

    # Harness: a requested formation is a hard constraint. Retry with
    # corrective feedback when the agent strays; force the shape as a last
    # resort so the coach always gets what they asked for.
    retries = 0
    while (
        formation
        and retries < 2
        and not _formation_ok(result, formation, team_size)
    ):
        retries += 1
        rows = _rows(formation)
        retry_prompt = (
            prompt
            + f"\n\nYour previous answer used formation "
            f"'{result.formation}' with positions "
            f"{[s.position for s in result.lineup]} — that is WRONG. "
            f"Return formation EXACTLY '{formation}': 1 GK plus rows of "
            f"{rows} players (defence → attack). Fix it."
        )
        result = (await agent.run(retry_prompt)).output
    if formation and not _formation_ok(result, formation, team_size):
        result = _force_formation(result, formation, team_size)
    return result


async def adjust_lineup(
    current_lineup: LineupResult, note: str, language: str | None = None
) -> AdjustResult:
    agent = build_agent("lineup_adjust", AdjustResult, ADJUST_PROMPT)
    current = ", ".join(f"{s.player} @ {s.position}" for s in current_lineup.lineup)
    lang_line = (
        f"Write `reason` in the language with ISO 639-1 code '{language}'.\n"
        if language
        else "Write `reason` in the same language as the coach's note.\n"
    )
    prompt = (
        f"Current formation: {current_lineup.formation}.\n"
        f"Current lineup: {current}.\n"
        f"In-match note: {note}.\n"
        + lang_line
        + "Suggest adjustments."
    )
    result = await agent.run(prompt)
    return result.output
