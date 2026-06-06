"""Audio → text transcription via OpenAI's audio API.

PydanticAI covers chat/structured output; transcription uses the OpenAI SDK
directly. The API key comes from OPENAI_API_KEY (set in app.config).
"""

from openai import AsyncOpenAI

from app.config import settings


async def transcribe_audio(data: bytes, filename: str) -> str:
    """Transcribe an uploaded audio clip to text."""
    client = AsyncOpenAI()  # reads OPENAI_API_KEY from the environment
    result = await client.audio.transcriptions.create(
        model=settings.transcribe_model,
        file=(filename, data),
    )
    return result.text
