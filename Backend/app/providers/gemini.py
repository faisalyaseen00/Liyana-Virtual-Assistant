import asyncio
import time

import httpx

from app.core.settings import settings
from app.providers.base import LLMMessage, LLMProvider

GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

# Gemini returns these when a model is overloaded or rate limited.
RETRYABLE_STATUS = {429, 500, 503}

# After a model reports it is overloaded, skip it for this long so later
# requests go straight to the next model instead of waiting on it again.
COOLDOWN_SECONDS = 60.0

# One shared client so requests reuse the open TLS connection to Google
# instead of doing a fresh handshake every message.
_client: httpx.AsyncClient | None = None

# model name -> monotonic time until which it is skipped
_cooldown_until: dict[str, float] = {}

# Models that rejected our thinkingConfig; send them none from then on.
_no_thinking_config: set[str] = set()


def _shared_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            # A stuck model should fail over quickly rather than hang the chat.
            timeout=httpx.Timeout(20.0, connect=5.0),
            http2=False,
        )
    return _client


class GeminiProvider(LLMProvider):
    supports_json_mode = True

    def __init__(self, client: httpx.AsyncClient | None = None):
        if not settings.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY is not set")
        self._client = client

    @property
    def client(self) -> httpx.AsyncClient:
        return self._client or _shared_client()

    def _models(self) -> list[str]:
        models = [settings.gemini_model]
        for name in (settings.gemini_fallback_model or "").split(","):
            name = name.strip()
            if name and name not in models:
                models.append(name)

        # The main (fast) model is always tried first: its overloads are
        # brief. Backups that just failed are skipped while cooling down.
        now = time.monotonic()
        backups = [m for m in models[1:] if _cooldown_until.get(m, 0) <= now]
        return [models[0]] + (backups or models[1:])

    def _body(self, model: str, messages: list[LLMMessage], json_mode: bool) -> dict:
        system_parts = [{"text": m.content} for m in messages if m.role == "system"]
        contents = [
            {
                "role": "model" if m.role == "assistant" else "user",
                "parts": [{"text": m.content}],
            }
            for m in messages
            if m.role != "system"
        ]

        generation_config: dict = {
            "maxOutputTokens": settings.gemini_max_output_tokens,
        }
        if settings.gemini_thinking_level and model not in _no_thinking_config:
            generation_config["thinkingConfig"] = {
                "thinkingLevel": settings.gemini_thinking_level,
            }
        if json_mode:
            generation_config["responseMimeType"] = "application/json"

        body: dict = {"contents": contents, "generationConfig": generation_config}
        if system_parts:
            body["systemInstruction"] = {"parts": system_parts}
        return body

    async def _post(self, model: str, body: dict) -> httpx.Response:
        return await self.client.post(
            f"{GEMINI_BASE_URL}/{model}:generateContent",
            headers={"x-goog-api-key": settings.gemini_api_key},
            json=body,
        )

    async def _try_models(
        self,
        models: list[str],
        messages: list[LLMMessage],
        json_mode: bool,
    ) -> httpx.Response | None:
        response: httpx.Response | None = None

        for model in models:
            try:
                response = await self._post(
                    model, self._body(model, messages, json_mode)
                )
            except httpx.TransportError:
                _cooldown_until[model] = time.monotonic() + COOLDOWN_SECONDS
                continue

            # Some models don't accept every thinking level; retry once
            # without it and remember that for next time.
            if (
                response.status_code == 400
                and "thinking" in response.text.lower()
                and model not in _no_thinking_config
            ):
                _no_thinking_config.add(model)
                response = await self._post(
                    model, self._body(model, messages, json_mode)
                )

            if response.status_code in RETRYABLE_STATUS:
                _cooldown_until[model] = time.monotonic() + COOLDOWN_SECONDS
                continue

            _cooldown_until.pop(model, None)
            break

        return response

    async def generate(
        self,
        messages: list[LLMMessage],
        json_mode: bool = False,
    ) -> str:
        response = await self._try_models(self._models(), messages, json_mode)

        # Overload spikes usually pass within a second; give the main model
        # one more quick try before giving up.
        if response is None or response.status_code in RETRYABLE_STATUS:
            await asyncio.sleep(0.8)
            retry = await self._try_models(
                [settings.gemini_model], messages, json_mode
            )
            response = retry or response

        if response is None:
            raise RuntimeError("Could not reach Gemini")
        response.raise_for_status()

        candidates = response.json().get("candidates") or []
        if not candidates:
            return ""
        parts = candidates[0].get("content", {}).get("parts") or []
        # Skip thought summaries if the model ever includes them.
        return "".join(
            p.get("text", "") for p in parts if not p.get("thought")
        ).strip()
