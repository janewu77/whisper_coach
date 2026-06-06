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
