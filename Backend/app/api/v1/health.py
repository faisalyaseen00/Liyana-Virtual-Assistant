from fastapi import APIRouter
from datetime import datetime, timezone

router = APIRouter(
    prefix="/health",
    tags=["Health"],
)


@router.get("")
def health():
    return {
        "status": "healthy",
        "service": "Sentinel AI API",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc),
    }