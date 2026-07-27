from uuid import UUID

from datetime import datetime
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.session import Session as UserSession

class SessionRepository:

    @staticmethod
    def create(
        db: Session,
        *,
        user_id: UUID,
        refresh_token_hash: str,
        device_info: str | None = None,
    ) -> UserSession:

        session = UserSession(
            user_id=user_id,
            refresh_token_hash=refresh_token_hash,
            device_info=device_info,
        )

        db.add(session)
        db.commit()
        db.refresh(session)

        return session

    @staticmethod
    def get_by_refresh_token_hash(
        db: Session,
        refresh_token_hash: str,
    ) -> UserSession | None:

        statement = select(UserSession).where(
            UserSession.refresh_token_hash == refresh_token_hash
        )

        return db.scalar(statement)

    @staticmethod
    def revoke(
        db: Session,
        session: UserSession,
    ) -> None:

        
        session.revoked_at = datetime.utcnow()

        db.commit()

    @staticmethod
    def update_last_used(
        db: Session,
        session: UserSession,
    ) -> None:

        session.last_used_at = datetime.utcnow()

        db.commit()