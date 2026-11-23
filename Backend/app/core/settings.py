from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Sentinel AI API"
    app_env: str = "development"
    debug: bool = True

    database_url: str
    secret_key: str

    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # Grok
    groq_api_key: str | None = None
    groq_model: str = "llama-3.1-8b-instant"
    groq_max_completion_tokens: int = 2048

    # Google Gemini
    gemini_api_key: str | None = None
    # flash-lite answers in about 1s; the others are backups (comma
    # separated) used only while the main model is overloaded.
    gemini_model: str = "gemini-flash-lite-latest"
    gemini_fallback_model: str | None = "gemini-3.5-flash,gemini-flash-latest"
    # Less thinking = faster replies. Empty to use the model's default.
    gemini_thinking_level: str | None = "minimal"
    gemini_max_output_tokens: int = 1024
    # Real-time voice (Gemini Live): starts answering in about 1.5s.
    gemini_live_model: str = "gemini-3.1-flash-live-preview"
    gemini_live_voice: str = "Kore"

    @field_validator("database_url")
    @classmethod
    def _use_psycopg3_driver(cls, value: str) -> str:
        """Hosts like Railway and Neon give URLs starting with postgres:// or
        postgresql://, which SQLAlchemy maps to psycopg2 (not installed).
        Point them at the psycopg 3 driver that is installed."""
        for prefix in ("postgres://", "postgresql://"):
            if value.startswith(prefix):
                return "postgresql+psycopg://" + value[len(prefix):]
        return value

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
    )


settings = Settings()