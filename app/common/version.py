"""
Version information router for services.
Provides build and runtime metadata via /version endpoint.
"""
import os
from datetime import datetime
from typing import Dict, Any

from fastapi import APIRouter

router = APIRouter(tags=["version"])


@router.get("/version")
async def get_version() -> Dict[str, Any]:
    """
    Return version and build information for the service.
    
    Returns:
        Dictionary containing:
        - version: Git SHA from build time
        - git_sha: Same as version (for clarity)
        - build_time: ISO 8601 timestamp when image was built
        - service: Service name (api or aux)
        - environment: Runtime environment from ENV var or 'unknown'
        - region: AWS region from ENV var or 'unknown'
    """
    return {
        "version": os.getenv("VERSION", "unknown"),
        "git_sha": os.getenv("VERSION", "unknown"),
        "build_time": os.getenv("BUILD_TIME", "unknown"),
        "service": os.getenv("SERVICE_NAME", "unknown"),
        "environment": os.getenv("ENVIRONMENT", "unknown"),
        "region": os.getenv("AWS_REGION", "unknown"),
    }
