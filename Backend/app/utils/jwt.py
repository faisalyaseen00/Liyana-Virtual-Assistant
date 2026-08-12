from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from jwt import InvalidTokenError

from app.core.settings import settings


def create_access_token(
    user_id: UUID,
    session_id: UUID,
) -> str:
    """
    Create a JWT access token for a specific user session.
    """
    expire = datetime.now(UTC) + timedelta(minutes=settings.access_token_expire_minutes)

    payload = {
        "sub": str(user_id),
        "session_id": str(session_id),
        "type": "access",
        "exp": expire,
    }

    return jwt.encode(
        payload,
        settings.secret_key,
        algorithm=settings.algorithm,
    )


def decode_token(token: str) -> dict:
    """
    Decode a JWT token and return its payload.
    Returns an empty dictionary if the token is invalid.
    """
    try:
        return jwt.decode(
            token,
            settings.secret_key,
            algorithms=[settings.algorithm],
        )
    except InvalidTokenError:
        return {}
