from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App configuration, read from environment / .env."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database — single SQLite file in the backend dir by default.
    db_url: str = "sqlite:///./wc.db"

    # PydanticAI / Claude. ANTHROPIC_API_KEY is read by pydantic-ai directly,
    # but we surface it here so startup can warn if it's missing.
    anthropic_api_key: str = ""
    llm_model: str = "anthropic:claude-opus-4-8"

    # CORS — open in dev so the Flutter app can call from anywhere.
    cors_origins: list[str] = ["*"]


settings = Settings()
