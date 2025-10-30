"""HTTP client for communicating with the Auxiliary service."""
import logging
import httpx
import os
from typing import Dict, List, Any, Optional
from fastapi import HTTPException

logger = logging.getLogger(__name__)


class AuxServiceClient:
    """Client for making requests to the Auxiliary service (internal AWS operations)."""
    
    def __init__(self):
        self.base_url = os.getenv(
            'AUX_SERVICE_URL',
            'http://aux.aux.svc.cluster.local:80'  # Kubernetes DNS
        )
        self.timeout = httpx.Timeout(10.0, connect=5.0)
        logger.info(f"AuxServiceClient initialized with base_url: {self.base_url}")
    
    async def _make_request(self, method: str, endpoint: str) -> Dict[str, Any]:
        """Make HTTP request to AUX service with error handling."""
        url = f"{self.base_url}{endpoint}"
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.request(method, url)
                response.raise_for_status()
                return response.json()
                
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error from AUX service: {e.response.status_code} - {e.response.text}")
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"AUX service error: {e.response.text}"
            )
        except httpx.TimeoutException:
            logger.error(f"Timeout calling AUX service: {url}")
            raise HTTPException(
                status_code=504,
                detail="Timeout connecting to internal service"
            )
        except httpx.ConnectError as e:
            logger.error(f"Connection error to AUX service: {e}")
            raise HTTPException(
                status_code=503,
                detail="Internal service unavailable"
            )
        except Exception as e:
            logger.error(f"Unexpected error calling AUX service: {e}")
            raise HTTPException(
                status_code=500,
                detail=f"Internal error: {str(e)}"
            )
    
    async def list_buckets(self) -> Dict[str, Any]:
        """List all S3 buckets via AUX service."""
        return await self._make_request("GET", "/s3/buckets")
    
    async def list_parameters(self) -> Dict[str, Any]:
        """List all SSM parameters via AUX service."""
        return await self._make_request("GET", "/parameters")
    
    async def get_parameter(self, parameter_name: str) -> Dict[str, Optional[str]]:
        """Get specific SSM parameter value via AUX service."""
        if not parameter_name.startswith('/'):
            parameter_name = f'/{parameter_name}'
        return await self._make_request("GET", f"/parameters{parameter_name}")


aux_client = AuxServiceClient()
