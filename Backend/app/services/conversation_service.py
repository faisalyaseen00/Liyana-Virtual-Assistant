from uuid import UUID

from sqlalchemy.orm import Session

from app.models.conversation import DEFAULT_TITLE, Conversation
from app.repositories.conversation_repository import ConversationRepository


TITLE_MAX_WORDS = 6
TITLE_MAX_CHARS = 60


def title_from_message(content: str) -> str:
    """A short conversation title from the first user message, e.g.
    "Remind me to call mom tomorrow…"."""
    words = content.split()
    if not words:
        return DEFAULT_TITLE

    title = " ".join(words[:TITLE_MAX_WORDS])
    truncated = len(words) > TITLE_MAX_WORDS

    if len(title) > TITLE_MAX_CHARS:
        title = title[:TITLE_MAX_CHARS].rsplit(" ", 1)[0] or title[:TITLE_MAX_CHARS]
        truncated = True

    title = title.rstrip(" .,;:!?")
    title = title[:1].upper() + title[1:]
    return f"{title}…" if truncated else title


class ConversationService:
    def __init__(self, db: Session):
        self.repository = ConversationRepository(db)

    def create_conversation(
        self,
        *,
        user_id: UUID,
        title: str = DEFAULT_TITLE,
    ) -> Conversation:

        return self.repository.create(
            user_id=user_id,
            title=title,
        )

    def get_conversation(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
    ) -> Conversation | None:

        return self.repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

    def get_user_conversations(
        self,
        *,
        user_id: UUID,
    ) -> list[Conversation]:

        return self.repository.get_by_user(user_id)

    def update_title(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        title: str,
    ) -> Conversation | None:

        conversation = self.repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return None

        self.repository.update_title(
            conversation,
            title,
        )

        return conversation

    def set_title_from_first_message(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        content: str,
    ) -> None:
        """Name the conversation after its first message, unless the user
        has already renamed it."""
        conversation = self.repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )
        if conversation is None or conversation.title not in (DEFAULT_TITLE, "New Chat"):
            return

        self.repository.update_title(conversation, title_from_message(content))

    def delete_conversation(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
    ) -> bool:

        conversation = self.repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return False

        self.repository.delete(conversation)

        return True