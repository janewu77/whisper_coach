import os

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App configuration, read from environment / .env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database. Defaults to local SQLite. For Postgres you can paste a plain
    # `postgresql://user:pass@host:5432/db` URL — it is normalized to the
    # psycopg (v3) driver automatically.
    db_url: str = "sqlite:///./wc.db"

    @field_validator("db_url")
    @classmethod
    def _use_psycopg_driver(cls, v: str) -> str:
        # SQLAlchemy maps bare postgres URLs to psycopg2 (not installed); pin v3.
        for prefix in ("postgresql://", "postgres://"):
            if v.startswith(prefix):
                return "postgresql+psycopg://" + v[len(prefix) :]
        return v

    # PydanticAI / OpenAI. OPENAI_API_KEY is read by pydantic-ai directly,
    # but we surface it here so startup can warn if it's missing.
    openai_api_key: str = ""
    # "openai-chat:" pins the Chat Completions API (avoids the v2 Responses
    # default). gpt-4o supports vision, needed by the roster extractor.
    llm_model: str = "openai-chat:gpt-4o"
    # Audio transcription model for voice notes (OpenAI audio API).
    transcribe_model: str = "whisper-1"

    # CORS — open in dev so the Flutter app can call from anywhere.
    cors_origins: list[str] = ["*"]


settings = Settings()

# pydantic-ai reads OPENAI_API_KEY from the process environment, so make the
# value from .env available to it (without clobbering an already-set env var).
if settings.openai_api_key and not os.environ.get("OPENAI_API_KEY"):
    os.environ["OPENAI_API_KEY"] = settings.openai_api_key
