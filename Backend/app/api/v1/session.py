from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.dependencies.auth import CurrentUser
from app.dependencies.db import get_db
from app.dependencies.session import CurrentSession
from app.schemas.session import SessionResponse
from app.services.session_service import SessionService

router = APIRouter(
    prefix="/sessions",
    tags=["Sessions"],
)


@router.get(
    "/",
    response_model=list[SessionResponse],
)
def get_sessions(
    current_user: CurrentUser,
    current_session: CurrentSession,
    db: Session = Depends(get_db),
):
    service = SessionService(db)

    return service.get_user_sessions(
        user=current_user,
        current_session=current_session,
    )


@router.delete(
    "/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def revoke_session(
    session_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    service = SessionService(db)

    service.revoke_session(
        session_id=session_id,
        user=current_user,
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/",
    status_code=status.HTTP_204_NO_CONTENT,
)
def revoke_other_sessions(
    current_user: CurrentUser,
    current_session: CurrentSession,
    db: Session = Depends(get_db),
):
    service = SessionService(db)

    service.revoke_other_sessions(
        user=current_user,
        current_session=current_session,
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)
