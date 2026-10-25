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
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
    )


settings = Settings()