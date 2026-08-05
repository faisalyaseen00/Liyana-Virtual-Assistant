from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    @staticmethod
    def get_by_email(db: Session, email: str) -> User | None:
        statement = select(User).where(User.email == email.lower())
        return db.scalar(statement)

    @staticmethod
    def get_by_id(db: Session, user_id: UUID) -> User | None:
        statement = select(User).where(User.id == user_id)
        return db.scalar(statement)

    @staticmethod
    def create(
        db: Session,
        *,
        email: str,
        hashed_password: str,
        full_name: str | None = None,
    ) -> User:

        user = User(
            email=email.lower(),
            hashed_password=hashed_password,
            full_name=full_name,
        )

        db.add(user)
        db.commit()
        db.refresh(user)

        return user
