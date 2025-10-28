"""Configuration router - SSM Parameter Store integration."""
from fastapi import APIRouter, HTTPException
from typing import Dict, List, Optional, Any
from common.aws_client import ssm_client
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/config")
async def list_all_parameters() -> Dict[str, Any]:
    """List all parameters stored in AWS Parameter Store."""
    try:
        parameters = ssm_client.list_all_parameters()
        return {
            "count": len(parameters),
            "parameters": parameters,
        }
    except Exception as e:
        logger.error(f"Error listing parameters: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/config/{parameter_name:path}")
async def get_parameter_value(parameter_name: str) -> Dict[str, Optional[str]]:
    """Retrieve the value of a specific parameter from AWS Parameter Store."""
    try:
        value = ssm_client.get_parameter(parameter_name)
        
        if value is None:
            raise HTTPException(
                status_code=404, 
                detail=f"Parameter '{parameter_name}' not found"
            )
        
        return {
            "name": parameter_name,
            "value": value,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching parameter {parameter_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
