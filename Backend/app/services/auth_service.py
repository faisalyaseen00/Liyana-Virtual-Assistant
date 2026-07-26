from sqlalchemy.orm import Session

from Backend.app.schemas import user
from Backend.app.schemas import user
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
        data.email,)

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
        pass

    @staticmethod
    def refresh_access_token(
        db: Session,
        refresh_token: str,
    ):
        pass

    @staticmethod
    def logout_user(
        db: Session,
        refresh_token: str,
    ):
        pass