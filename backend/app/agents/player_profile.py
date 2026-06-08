"""Player profiler — builds a structured player profile from a coach's spoken or
typed description (used by the player detail screen's voice/text "describe").

Returns the player's COMPLETE intended profile (merging the new info with the
current one), so the client can just replace the fields the agent fills in.
"""

import json

from app.agents import build_agent
from app.schemas import PlayerProfileResult

SYSTEM_PROMPT = (
    "You build a football player's profile from a coach's description. Extract:\n"
    "- number: jersey number\n"
    "- positions: positions the player can play, as standard codes "
    "(GK, CB, LB, RB, LWB, RWB, CDM, CM, CAM, LM, RM, LW, RW, ST)\n"
    "- preferred_foot: 'left', 'right', or 'both'\n"
    "- height_cm: height in centimetres\n"
    "- traits: short skill/quality tags (e.g. 'strong', 'fast', "
    "'good ball control', 'good passing', 'good finishing', 'stamina', 'aerial')\n"
    "- description: a concise 1-2 sentence scouting summary\n\n"
    "Return the player's COMPLETE updated profile, merging the new information "
    "with the current profile provided. Keep existing positions/traits unless the "
    "description contradicts them. Only set scalar fields (number, foot, height) "
    "when the text or current profile gives them; otherwise leave them null."
)


async def extract_profile(text: str, current: dict) -> PlayerProfileResult:
    """Merge `text` into `current` (a player's profile dict) → full profile."""
    agent = build_agent("player_profile", PlayerProfileResult, SYSTEM_PROMPT)
    prompt = (
        f"Current profile:\n{json.dumps(current, ensure_ascii=False)}\n\n"
        f"Coach's description:\n{text}\n\n"
        "Return the updated complete profile."
    )
    result = await agent.run(prompt)
    return result.output
