"""S3 storage endpoints."""
import logging
from fastapi import APIRouter, HTTPException

from common.aws_client import s3_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/storage")


@router.get("")
async def list_buckets():
    """List all S3 buckets in the AWS account."""
    try:
        buckets = s3_client.list_buckets()
        return {
            "count": len(buckets),
            "buckets": buckets
        }
    except Exception as e:
        logger.error(f"Error listing S3 buckets: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list S3 buckets: {str(e)}")
