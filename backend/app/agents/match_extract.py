"""Match extractor — turns a fixtures photo or a spoken/typed schedule into a
list of matches for the create-review step (and to fill the match detail form).
"""

from datetime import date as _date

from pydantic_ai import BinaryContent

from app.agents import build_agent
from app.schemas import MatchExtractResult

SYSTEM_PROMPT = (
    "You extract upcoming football match fixtures for the coach's own team. For "
    "each match return: `opponent` (the OTHER team); `is_home` = true if OUR "
    "team plays at home, false if away (from 'H'/'A', 'home'/'away', or 'vs' vs "
    "'@'); `date` as YYYY-MM-DD when determinable; `kickoff_time` as 'HH:MM' "
    "(24h) if shown; `pitch` (the ground/venue name) if shown; `address` (the "
    "venue's street address, one line) if shown; `strength` as "
    "'strong' or 'weak' only when clearly implied (else null); and a short "
    "`note` if useful. Resolve relative dates ('Saturday', 'next week') against "
    "the given today's date. Extract EVERY match you find; if only one is "
    "described, return a single match."
)


def _today() -> str:
    return f"Today is {_date.today().isoformat()}."


async def extract_matches_from_image(
    image_bytes: bytes, media_type: str
) -> MatchExtractResult:
    agent = build_agent("match_extract", MatchExtractResult, SYSTEM_PROMPT)
    result = await agent.run(
        [
            f"{_today()} Extract the fixtures from this image.",
            BinaryContent(data=image_bytes, media_type=media_type),
        ]
    )
    return result.output


async def extract_matches_from_text(text: str) -> MatchExtractResult:
    agent = build_agent("match_extract_text", MatchExtractResult, SYSTEM_PROMPT)
    result = await agent.run(f"{_today()}\nFixtures described: {text}")
    return result.output
