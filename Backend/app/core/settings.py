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
    groq_api_key: str
    groq_model: str = "llama-3.1-8b-instant"
    groq_max_completion_tokens: int = 2048

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