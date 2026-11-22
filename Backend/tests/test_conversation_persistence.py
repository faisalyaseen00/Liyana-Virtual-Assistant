from sqlalchemy import select

import app.db.models
from app.db.session import SessionLocal
from app.models.enums import MessageRole
from app.models.user import User
from app.repositories.conversation_repository import ConversationRepository
from app.repositories.message_repository import MessageRepository


def main() -> None:
    db = SessionLocal()

    try:
        print("Database connection: OK")

        user = db.scalar(
            select(User).order_by(User.created_at.asc())
        )

        if user is None:
            print("No user found. Create a registered user first.")
            return

        print(f"Using user: {user.email}")
        print(f"User ID: {user.id}")

        conversation_repository = ConversationRepository(db)
        message_repository = MessageRepository(db)

        conversation = conversation_repository.create(
            user_id=user.id,
            title="Persistence Test",
        )

        print(f"\nConversation created: {conversation.id}")

        message = message_repository.create(
            conversation_id=conversation.id,
            role=MessageRole.USER,
            content="This is a persistence test.",
        )

        print(f"Message created: {message.id}")

        messages = message_repository.get_by_conversation(
            conversation.id
        )

        print(f"\nMessages retrieved: {len(messages)}")

        for item in messages:
            print(
                f"- [{item.role.value}] "
                f"{item.content}"
            )

        print("\nPersistence test: PASSED")

    finally:
        db.close()


if __name__ == "__main__":
    main()