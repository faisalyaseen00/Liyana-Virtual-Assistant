from datetime import datetime, timezone
UTC = timezone.utc
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.dependencies.db import get_db
from app.models.session import Session as UserSession
from app.repositories.session_repository import SessionRepository
from app.utils.jwt import decode_token

security = HTTPBearer()


def get_current_session(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> UserSession:

    payload = decode_token(credentials.credentials)

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token.",
        )

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type.",
        )

    session_id = payload.get("session_id")
    user_id = payload.get("sub")

    if session_id is None or user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session ID missing from token.",
        )

    repository = SessionRepository(db)

    session = repository.get_by_id(UUID(session_id))

    if session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session not found.",
        )

    if not session.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been revoked.",
        )

    if str(session.user_id) != user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session does not belong to this user.",
        )

    expires_at = session.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)

    if expires_at <= datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has expired.",
        )
    repository.update_activity(session)

    return session


CurrentSession = Annotated[
    UserSession,
    Depends(get_current_session),
]
