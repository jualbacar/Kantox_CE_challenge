"""Health check router."""
from fastapi import APIRouter
from datetime import datetime
from common.config import settings

router = APIRouter()


@router.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": settings.service_name,
        "environment": settings.environment,
        "timestamp": datetime.utcnow().isoformat(),
    }
