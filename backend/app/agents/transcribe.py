"""Audio → text transcription via OpenAI's audio API.

PydanticAI covers chat/structured output; transcription uses the OpenAI SDK
directly. The API key comes from OPENAI_API_KEY (set in app.config).
"""

from openai import AsyncOpenAI

from app.config import settings


async def transcribe_audio(
    data: bytes, filename: str, language: str | None = None
) -> str:
    """Transcribe an uploaded audio clip to text.

    `language` is an optional ISO-639-1 code (e.g. "en", "zh", "de") — the
    speaker's language, from the user's profile. When given it improves
    accuracy; when omitted the model auto-detects.
    """
    client = AsyncOpenAI()  # reads OPENAI_API_KEY from the environment
    kwargs = {"language": language} if language else {}
    result = await client.audio.transcriptions.create(
        model=settings.transcribe_model,
        file=(filename, data),
        **kwargs,
    )
    return result.text
