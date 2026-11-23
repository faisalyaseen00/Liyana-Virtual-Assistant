from app.core.settings import settings
from app.providers.base import LLMProvider


def get_default_provider() -> LLMProvider:
    """Use Gemini when a Gemini key is configured, otherwise Groq."""
    if settings.gemini_api_key:
        from app.providers.gemini import GeminiProvider

        return GeminiProvider()

    from app.providers.grok import GrokProvider

    return GrokProvider()
