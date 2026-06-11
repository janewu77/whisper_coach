"""Style distiller — turns example texts written/spoken by one person into a
compact "style card" describing HOW they express themselves. The card is
stored on the user and injected into every match-summary prompt, so reports
come out in that voice.
"""

from app.agents import build_agent
from app.schemas import StyleCardResult

SYSTEM_PROMPT = (
    "You analyse example texts written or spoken by one person and distill "
    "HOW they express themselves — never the specific content. Produce a "
    "compact style card (under 250 words) covering: overall voice and tone, "
    "sentence rhythm and length, typical vocabulary and filler words, "
    "catchphrases, humour, perspective, clear dos and don'ts, plus 2-3 SHORT "
    "invented example phrases that sound like them. The card will be used to "
    "imitate the style in other languages too, so describe the style rather "
    "than just quoting."
)


async def distill_style(text: str) -> StyleCardResult:
    agent = build_agent("style_distiller", StyleCardResult, SYSTEM_PROMPT)
    result = await agent.run(
        f"Example texts:\n{text}\n\nProduce the style card."
    )
    return result.output
