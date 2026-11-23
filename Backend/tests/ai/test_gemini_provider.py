import httpx
import pytest

from app.core.settings import settings
from app.providers import gemini
from app.providers.base import LLMMessage
from app.providers.gemini import GeminiProvider


def _ok(text: str) -> httpx.Response:
    return httpx.Response(
        200, json={"candidates": [{"content": {"parts": [{"text": text}]}}]}
    )


@pytest.fixture(autouse=True)
def gemini_settings(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")
    monkeypatch.setattr(settings, "gemini_model", "fast")
    monkeypatch.setattr(settings, "gemini_fallback_model", "backup")
    monkeypatch.setattr(settings, "gemini_thinking_level", "minimal")
    gemini._cooldown_until.clear()
    gemini._no_thinking_config.clear()
    monkeypatch.setattr(gemini.asyncio, "sleep", _no_sleep)


async def _no_sleep(_seconds):
    return None


def _provider(handler) -> tuple[GeminiProvider, list[str]]:
    seen: list[str] = []

    def record(request: httpx.Request) -> httpx.Response:
        seen.append(request.url.path.rsplit("/", 1)[-1].split(":")[0])
        return handler(request)

    client = httpx.AsyncClient(transport=httpx.MockTransport(record))
    return GeminiProvider(client=client), seen


@pytest.mark.asyncio
async def test_uses_backup_when_main_model_overloaded():
    def handler(request):
        if "/fast:" in request.url.path:
            return httpx.Response(503, json={"error": {"code": 503}})
        return _ok("from backup")

    provider, seen = _provider(handler)
    reply = await provider.generate([LLMMessage("user", "hi")])

    assert reply == "from backup"
    assert seen == ["fast", "backup"]


@pytest.mark.asyncio
async def test_retries_without_unsupported_thinking_level():
    def handler(request):
        if b"thinkingConfig" in request.content:
            return httpx.Response(400, text="Thinking level MINIMAL is not supported")
        return _ok("ok")

    provider, seen = _provider(handler)
    reply = await provider.generate([LLMMessage("user", "hi")])

    assert reply == "ok"
    assert seen == ["fast", "fast"]
    assert "fast" in gemini._no_thinking_config


@pytest.mark.asyncio
async def test_system_prompt_and_roles_are_mapped():
    captured = {}

    def handler(request):
        import json

        captured.update(json.loads(request.content))
        return _ok("ok")

    provider, _ = _provider(handler)
    await provider.generate(
        [
            LLMMessage("system", "be nice"),
            LLMMessage("user", "hi"),
            LLMMessage("assistant", "hello"),
        ],
        json_mode=True,
    )

    assert captured["systemInstruction"] == {"parts": [{"text": "be nice"}]}
    assert [c["role"] for c in captured["contents"]] == ["user", "model"]
    assert captured["generationConfig"]["responseMimeType"] == "application/json"
