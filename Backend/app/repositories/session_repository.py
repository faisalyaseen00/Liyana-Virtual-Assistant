from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.session import Session as UserSession


class SessionRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        *,
        user_id: UUID,
        refresh_token_hash: str,
        device_name: str | None = None,
        device_type: str | None = None,
        browser: str | None = None,
        operating_system: str | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        is_active: bool = True,
        expires_at: datetime | None = None,
    ) -> UserSession:

        session = UserSession(
            user_id=user_id,
            refresh_token_hash=refresh_token_hash,
            device_name=device_name,
            device_type=device_type,
            browser=browser,
            operating_system=operating_system,
            ip_address=ip_address,
            user_agent=user_agent,
            is_active=is_active,
        )

        if expires_at is not None:
            session.expires_at = expires_at

        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)

        return session

    def get_by_refresh_token_hash(
        self,
        refresh_token_hash: str,
    ) -> UserSession | None:

        statement = select(UserSession).where(
            UserSession.refresh_token_hash == refresh_token_hash
        )

        return self.db.scalar(statement)

    def get_by_id(
        self,
        session_id: UUID,
    ) -> UserSession | None:

        statement = select(UserSession).where(UserSession.id == session_id)

        return self.db.scalar(statement)

    def get_by_user(
        self,
        user_id: UUID,
    ) -> list[UserSession]:

        statement = (
            select(UserSession)
            .where(
                UserSession.user_id == user_id,
                UserSession.is_active.is_(True),
                UserSession.revoked_at.is_(None),
            )
            .order_by(UserSession.created_at.desc())
        )

        return list(self.db.scalars(statement).all())

    def revoke(
        self,
        session: UserSession,
    ) -> None:

        now = datetime.now(UTC)

        session.is_active = False
        session.revoked_at = now
        session.updated_at = now

        self.db.commit()
        self.db.refresh(session)

    def revoke_all_except(
        self,
        user_id: UUID,
        current_session_id: UUID,
    ) -> None:

        now = datetime.now(UTC)

        sessions = self.db.scalars(
            select(UserSession).where(
                UserSession.user_id == user_id,
                UserSession.id != current_session_id,
                UserSession.is_active.is_(True),
            )
        ).all()

        for session in sessions:
            session.is_active = False
            session.revoked_at = now
            session.updated_at = now

        self.db.commit()

    def update_activity(
        self,
        session: UserSession,
    ) -> None:

        now = datetime.now(UTC)

        session.last_activity_at = now
        session.updated_at = now

        self.db.commit()
        self.db.refresh(session)
