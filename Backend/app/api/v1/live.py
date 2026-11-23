import asyncio
import contextlib
import json
import logging

from fastapi import APIRouter, Depends, HTTPException, WebSocket
from sqlalchemy.orm import Session
from starlette.websockets import WebSocketDisconnect, WebSocketState

from app.core.settings import settings
from app.dependencies.auth import authenticate_access_token
from app.dependencies.db import get_db
from app.services import live_voice

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Live voice"])

# Close codes the app can show a clear message for.
CLOSE_UNAUTHORIZED = 4401
CLOSE_UNAVAILABLE = 4503


@router.websocket("/live")
async def live_voice_ws(websocket: WebSocket, db: Session = Depends(get_db)):
    """Real-time voice chat with Liyana. The first message must be
    {"type": "auth", "token": "<access token>"}; see app.services.live_voice
    for the rest of the protocol."""
    await websocket.accept()

    try:
        first = json.loads(
            await asyncio.wait_for(websocket.receive_text(), timeout=10)
        )
        user = authenticate_access_token(str(first.get("token") or ""), db)
    except (asyncio.TimeoutError, ValueError, AttributeError, HTTPException, WebSocketDisconnect):
        await _close(websocket, CLOSE_UNAUTHORIZED, "Please sign in again.")
        return

    if not settings.gemini_api_key:
        await _close(websocket, CLOSE_UNAVAILABLE, "Live voice is not set up.")
        return

    try:
        gemini = await live_voice.open_gemini_connection()
    except Exception:
        logger.exception("Could not connect to Gemini Live")
        await _close(websocket, CLOSE_UNAVAILABLE, "Liyana's voice is unavailable.")
        return

    session = live_voice.LiveVoiceSession(
        db=db,
        user=user,
        gemini=gemini,
        send_json=websocket.send_json,
        send_bytes=websocket.send_bytes,
    )

    try:
        await asyncio.wait_for(session.start(), timeout=15)
        await live_voice.run_session(session, websocket.receive)
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("Live voice session failed")
        await _close(websocket, CLOSE_UNAVAILABLE, "Liyana's voice was interrupted.")
        return
    finally:
        with contextlib.suppress(Exception):
            await gemini.close()

    await _close(websocket, 1000, "Bye!")


async def _close(websocket: WebSocket, code: int, reason: str) -> None:
    if websocket.application_state == WebSocketState.CONNECTED:
        try:
            await websocket.close(code=code, reason=reason)
        except RuntimeError:
            pass
