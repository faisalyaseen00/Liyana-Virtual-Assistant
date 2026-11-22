from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.utils.dates import is_valid_timezone


class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str | None
    profile_picture: str | None
    timezone: str
    language: str
    is_active: bool
    is_verified: bool

    model_config = ConfigDict(
        from_attributes=True,
    )


class UpdateUserRequest(BaseModel):
    full_name: str | None = Field(
        default=None,
        max_length=255,
    )

    profile_picture: str | None = Field(
        default=None,
        max_length=500,
    )

    timezone: str | None = Field(
        default=None,
        max_length=100,
    )

    language: str | None = Field(
        default=None,
        max_length=50,
    )

    @field_validator("timezone")
    @classmethod
    def _known_timezone(cls, value: str | None) -> str | None:
        if value is not None and not is_valid_timezone(value):
            raise ValueError("Unknown time zone; use an IANA name like Asia/Karachi")
        return value
