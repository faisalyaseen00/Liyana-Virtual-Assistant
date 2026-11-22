from datetime import datetime, timedelta, timezone
UTC = timezone.utc

from sqlalchemy.orm import Session

from app.core.device import parse_user_agent
from app.core.settings import settings
from app.core.security import (
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import (
    LoginRequest,
    RegisterRequest,
    TokenResponse,
)
from app.utils.jwt import create_access_token


class AuthService:
    @staticmethod
    def register_user(
        db: Session,
        data: RegisterRequest,
    ):
        existing_user = UserRepository.get_by_email(
            db,
            data.email,
        )

        if existing_user:
            raise ValueError("Email already registered")

        hashed_password = hash_password(data.password)
        user = UserRepository.create(
            db=db,
            email=data.email,
            hashed_password=hashed_password,
            full_name=data.full_name,
        )
        return user

    @staticmethod
    def login_user(
        db: Session,
        data: LoginRequest,
        user_agent: str | None = None,
        ip_address: str | None = None,
    ):
        # Find user
        user = UserRepository.get_by_email(
            db,
            data.email,
        )

        if not user:
            raise ValueError("Invalid email or password")

        if not user.is_active:
            raise ValueError("User account is disabled")

        # Verify password
        if not verify_password(
            data.password,
            user.hashed_password,
        ):
            raise ValueError("Invalid email or password")

        # Parse device information
        device = parse_user_agent(user_agent)

        session_repository = SessionRepository(db)

        refresh_token = generate_refresh_token()

        refresh_token_hash = hash_refresh_token(
            refresh_token,
        )

        # Create session
        session = session_repository.create(
            user_id=user.id,
            refresh_token_hash=refresh_token_hash,
            device_name=device["device_name"],
            device_type=device["device_type"],
            browser=device["browser"],
            operating_system=device["operating_system"],
            ip_address=ip_address,
            user_agent=user_agent,
            is_active=True,
            expires_at=datetime.now(UTC) + timedelta(
                days=settings.refresh_token_expire_days,
            ),
        )

        user.last_login_at = datetime.now(UTC)
        db.commit()
        db.refresh(user)

        # Generate access token after the session has been persisted.
        access_token = create_access_token(
            user.id,
            session.id,
        )

        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
        )

    @staticmethod
    def refresh_access_token(
        db: Session,
        refresh_token: str,
    ):
        refresh_token_hash = hash_refresh_token(refresh_token)

        session_repository = SessionRepository(db)

        session = session_repository.get_by_refresh_token_hash(
            refresh_token_hash,
        )

        if not session:
            raise ValueError("Invalid refresh token")

        if session.revoked_at is not None:
            raise ValueError("Session has been revoked")

        expires_at = session.expires_at

        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=UTC)

        if expires_at < datetime.now(UTC):
            raise ValueError("Refresh token expired")

        user = UserRepository.get_by_id(
            db,
            session.user_id,
        )

        if not user:
            raise ValueError("User not found")

        session_repository.update_activity(
            session,
        )

        access_token = create_access_token(
            user.id,
            session.id,
        )

        return {
            "access_token": access_token,
            "token_type": "bearer",
        }

    @staticmethod
    def logout_user(
        db: Session,
        refresh_token: str,
    ):
        refresh_token_hash = hash_refresh_token(refresh_token)

        session_repository = SessionRepository(db)

        session = session_repository.get_by_refresh_token_hash(
            refresh_token_hash,
        )

        if not session:
            raise ValueError("Invalid refresh token")

        if session.revoked_at is not None:
            return

        session_repository.revoke(
            session,
        )
