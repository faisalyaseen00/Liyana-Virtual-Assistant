from uuid import UUID

from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.user import UpdateUserRequest


class UserService:
    @staticmethod
    def get_user_by_id(
        db: Session,
        user_id: UUID,
    ) -> User:

        user = db.query(User).filter(User.id == user_id).first()

        if not user:
            raise ValueError("User not found.")

        return user

    @staticmethod
    def update_user(
        db: Session,
        user: User,
        data: UpdateUserRequest,
    ) -> User:

        update_data = data.model_dump(
            exclude_unset=True,
            exclude_none=True,
        )

        for field, value in update_data.items():
            setattr(user, field, value)

        db.commit()
        db.refresh(user)

        return user
