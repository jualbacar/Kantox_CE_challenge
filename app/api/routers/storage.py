"""S3 storage endpoints - proxies to AUX service."""
import logging
from fastapi import APIRouter

from api.aux_client import aux_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/storage")


@router.get("")
async def list_buckets():
    """List all S3 buckets in the AWS account (via AUX service)."""
    logger.info("Proxying S3 bucket list request to AUX service")
    return await aux_client.list_buckets()
