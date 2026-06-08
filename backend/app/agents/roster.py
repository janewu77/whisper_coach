from pydantic_ai import BinaryContent

from app.agents import build_agent
from app.schemas import RosterResult

SYSTEM_PROMPT = (
    "You extract a football team roster from a photo of a team sheet or "
    "player list. Return every player's name, and their jersey number and "
    "preferred position when visible. Ignore coaches, headers, and any "
    "non-player text. If a field is not shown, leave it null."
)


async def extract_roster(image_bytes: bytes, media_type: str) -> RosterResult:
    """Run the roster extractor on an uploaded image."""
    agent = build_agent("roster", RosterResult, SYSTEM_PROMPT)
    result = await agent.run(
        [
            "Extract the players from this team sheet.",
            BinaryContent(data=image_bytes, media_type=media_type),
        ]
    )
    return result.output


TEXT_SYSTEM_PROMPT = (
    "You convert a coach's spoken or typed description into football players to "
    "add to a team roster. Extract each player's name, plus their jersey number "
    "and preferred position when stated. If a field is not mentioned, leave it "
    "null. Return only the players the coach intends to add — ignore filler words."
)


async def extract_players_from_text(text: str) -> RosterResult:
    """Parse free-text / transcribed speech into players to add to the roster."""
    agent = build_agent("roster_text", RosterResult, TEXT_SYSTEM_PROMPT)
    result = await agent.run(f"Players to add: {text}")
    return result.output
