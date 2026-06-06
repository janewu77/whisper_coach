import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App configuration, read from environment / .env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database. Defaults to local SQLite; set DB_URL for Postgres, e.g.
    # postgresql+psycopg://docker:docker@localhost:5432/whisper_coach
    db_url: str = "sqlite:///./wc.db"

    # PydanticAI / OpenAI. OPENAI_API_KEY is read by pydantic-ai directly,
    # but we surface it here so startup can warn if it's missing.
    openai_api_key: str = ""
    llm_model: str = "openai:gpt-4o"

    # CORS — open in dev so the Flutter app can call from anywhere.
    cors_origins: list[str] = ["*"]


settings = Settings()

# pydantic-ai reads OPENAI_API_KEY from the process environment, so make the
# value from .env available to it (without clobbering an already-set env var).
if settings.openai_api_key and not os.environ.get("OPENAI_API_KEY"):
    os.environ["OPENAI_API_KEY"] = settings.openai_api_key
