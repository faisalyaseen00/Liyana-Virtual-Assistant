from datetime import datetime, timezone
UTC = timezone.utc

from fastapi import APIRouter

from app.core.settings import settings
router = APIRouter(
    prefix="/health",
    tags=["Health"],
)


@router.get("")
def health():
    return {
        "status": "healthy",
        "service": settings.app_name,
        "version": "1.0.0",
        "timestamp": datetime.now(UTC),
    }
