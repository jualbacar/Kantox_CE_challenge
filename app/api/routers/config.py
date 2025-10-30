"""Configuration router - SSM Parameter Store integration (proxies to AUX service)."""
from fastapi import APIRouter
from typing import Dict, Optional, Any
from api.aux_client import aux_client
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/config")
async def list_all_parameters() -> Dict[str, Any]:
    """List all parameters stored in AWS Parameter Store (via AUX service)."""
    logger.info("Proxying parameter list request to AUX service")
    return await aux_client.list_parameters()


@router.get("/config/{parameter_name:path}")
async def get_parameter_value(parameter_name: str) -> Dict[str, Optional[str]]:
    """Retrieve the value of a specific parameter from AWS Parameter Store (via AUX service)."""
    logger.info(f"Proxying parameter get request for '{parameter_name}' to AUX service")
    return await aux_client.get_parameter(parameter_name)
