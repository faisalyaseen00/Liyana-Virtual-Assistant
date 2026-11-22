from datetime import date, datetime, time, timezone
from uuid import UUID, uuid4

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String, Time
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

UTC = timezone.utc


class Reminder(Base):
    __tablename__ = "reminders"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    user: Mapped["User"] = relationship("User", back_populates="reminders")

    title: Mapped[str] = mapped_column(String(255), nullable=False)

    # Stored as the user's local date and time, exactly as they said it.
    remind_date: Mapped[date] = mapped_column(Date, nullable=False)

    remind_time: Mapped[time | None] = mapped_column(Time, nullable=True)

    is_done: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

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
