import asyncio

import httpx

from app.core.settings import settings
from app.providers.base import LLMMessage, LLMProvider

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

# Gemini returns these when a model is overloaded or rate limited.
RETRYABLE_STATUS = {429, 500, 503}
ATTEMPTS_PER_MODEL = 2


class GeminiProvider(LLMProvider):
    def __init__(self, client: httpx.AsyncClient | None = None):
        if not settings.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY is not set")
        self.client = client or httpx.AsyncClient(timeout=60)

    async def generate(self, messages: list[LLMMessage]) -> str:
        # Gemini takes system prompts separately and calls the assistant "model".
        system_parts = [
            {"text": m.content} for m in messages if m.role == "system"
        ]
        contents = [
            {
                "role": "model" if m.role == "assistant" else "user",
                "parts": [{"text": m.content}],
            }
            for m in messages
            if m.role != "system"
        ]

        body: dict = {
            "contents": contents,
            "generationConfig": {
                "maxOutputTokens": settings.gemini_max_output_tokens,
            },
        }
        if system_parts:
            body["systemInstruction"] = {"parts": system_parts}

        models = [settings.gemini_model]
        if settings.gemini_fallback_model and settings.gemini_fallback_model != settings.gemini_model:
            models.append(settings.gemini_fallback_model)

        response = None
        for model in models:
            for attempt in range(ATTEMPTS_PER_MODEL):
                response = await self.client.post(
                    f"{GEMINI_BASE_URL}/{model}:generateContent",
                    headers={"x-goog-api-key": settings.gemini_api_key},
                    json=body,
                )
                if response.status_code not in RETRYABLE_STATUS:
                    break
                if attempt + 1 < ATTEMPTS_PER_MODEL:
                    await asyncio.sleep(1.5 * (attempt + 1))
            if response.status_code not in RETRYABLE_STATUS:
                break

        response.raise_for_status()
        data = response.json()

        candidates = data.get("candidates") or []
        if not candidates:
            return ""
        parts = candidates[0].get("content", {}).get("parts") or []
        return "".join(p.get("text", "") for p in parts).strip()
