from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class User(Base):
    __tablename__ = "users"

    # ==========================
    # Primary Key
    # ==========================
    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    # ==========================
    # Authentication
    # ==========================
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )

    hashed_password: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    # ==========================
    # Profile Information
    # ==========================
    full_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

    profile_picture: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    timezone: Mapped[str] = mapped_column(
        String(100),
        default="UTC",
        nullable=False,
    )

    language: Mapped[str] = mapped_column(
        String(50),
        default="en",
        nullable=False,
    )

    # ==========================
    # Account Status
    # ==========================
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # ==========================
    # Login Information
    # ==========================
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # ==========================
    # Relationships
    # ==========================
    sessions = relationship(
        "Session",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    # ==========================
    # Audit Fields
    # ==========================
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )