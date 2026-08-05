from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class SessionResponse(BaseModel):
    id: UUID

    device_name: str | None = None
    browser: str | None = None
    operating_system: str | None = None
    ip_address: str | None = None

    created_at: datetime
    last_activity_at: datetime

    is_current: bool = False

    model_config = ConfigDict(from_attributes=True)
