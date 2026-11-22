from datetime import datetime, timezone
UTC = timezone.utc
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

# Title of a conversation until it gets one from its first message.
DEFAULT_TITLE = "New Conversation"


class Conversation(Base):
    __tablename__ = "conversations"

    # ==========================
    # Primary Key
    # ==========================
    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    # ==========================
    # Relationship
    # ==========================
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    user: Mapped["User"] = relationship(
        "User",
        back_populates="conversations",
    )

    # ==========================
    # Conversation Information
    # ==========================
    title: Mapped[str] = mapped_column(
        String(255),
        default=DEFAULT_TITLE,
        nullable=False,
    )

    # ==========================
    # Relationships
    # ==========================
    messages: Mapped[list["Message"]] = relationship(
        "Message",
        back_populates="conversation",
        cascade="all, delete-orphan",
    )

    # ==========================
    # Audit Fields
    # ==========================
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        nullable=False,
    )

    last_message_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        nullable=False,
    )