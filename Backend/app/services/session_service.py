from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.session import Session as UserSession
from app.models.user import User
from app.repositories.session_repository import SessionRepository
from app.schemas.session import SessionResponse


class SessionService:
    """
    Business logic for user sessions.
    """

    def __init__(self, db: Session):
        self.db = db
        self.session_repository = SessionRepository(db)

    def get_user_sessions(
        self,
        user: User,
        current_session: UserSession,
    ) -> list[SessionResponse]:

        sessions = self.session_repository.get_by_user(user.id)

        results = []

        for session in sessions:
            item = SessionResponse.model_validate(session)
            item.is_current = session.id == current_session.id
            results.append(item)

        return results

    def revoke_session(
        self,
        session_id: UUID,
        user: User,
    ) -> None:

        session = self.session_repository.get_by_id(session_id)

        if session is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Session not found.",
            )

        if session.user_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not allowed to revoke this session.",
            )

        self.session_repository.revoke(session)

    def revoke_other_sessions(
        self,
        user: User,
        current_session: UserSession,
    ) -> None:

        self.session_repository.revoke_all_except(
            user.id,
            current_session.id,
        )

    def update_last_activity(
        self,
        session: UserSession,
    ) -> None:

        self.session_repository.update_activity(session)
