from sqlalchemy.orm import Session
from datetime import datetime
from app.core.security import (
    hash_password,
    verify_password,
    generate_refresh_token,
    hash_refresh_token,
)

from app.repositories.user_repository import UserRepository
from app.repositories.session_repository import SessionRepository

from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
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
        device_info: str | None = None,
    ):
        
        user = UserRepository.get_by_email(
        db,
        data.email,
    )

        if not user:
            raise ValueError("Invalid email or password")

        if not verify_password(
            data.password,
            user.hashed_password,
        ):
            raise ValueError("Invalid email or password")

        access_token = create_access_token(user.id)

        refresh_token = generate_refresh_token()

        refresh_token_hash = hash_refresh_token(refresh_token)

        SessionRepository.create(
            db=db,
            user_id=user.id,
            refresh_token_hash=refresh_token_hash,
            device_info=device_info,
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

        session = SessionRepository.get_by_refresh_token_hash(
            db,
            refresh_token_hash,
        )

        if not session:
            raise ValueError("Invalid refresh token")

        if session.revoked_at is not None:
            raise ValueError("Session has been revoked")

        if session.expires_at < datetime.utcnow():
            raise ValueError("Refresh token expired")

        user = UserRepository.get_by_id(
            db,
            session.user_id,
        )

        if not user:
            raise ValueError("User not found")

        SessionRepository.update_last_used(
            db,
            session,
        )

        access_token = create_access_token(user.id)

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

        session = SessionRepository.get_by_refresh_token_hash(
            db,
            refresh_token_hash,
        )

        if not session:
            raise ValueError("Invalid refresh token")

        if session.revoked_at is not None:
            return

        SessionRepository.revoke(
            db,
            session,
        )