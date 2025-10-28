"""AWS client wrappers for S3 and SSM Parameter Store."""
import logging
from typing import Dict, List, Optional, Any
import boto3
from botocore.exceptions import ClientError

from .config import settings

logger = logging.getLogger(__name__)


class S3Client:
    """Wrapper for AWS S3 operations."""
    
    def __init__(self):
        self.client = boto3.client('s3', region_name=settings.aws_region)
    
    def list_buckets(self) -> List[Dict[str, Any]]:
        """List all S3 buckets in the AWS account."""
        try:
            response = self.client.list_buckets()
            
            return [
                {
                    "name": bucket['Name'],
                    "creation_date": bucket['CreationDate'].isoformat(),
                }
                for bucket in response.get('Buckets', [])
            ]
        except ClientError as e:
            logger.error(f"Error listing S3 buckets: {e}")
            raise


class SSMClient:
    """Wrapper for AWS Systems Manager Parameter Store operations."""
    
    def __init__(self):
        self.client = boto3.client('ssm', region_name=settings.aws_region)
    
    def get_parameter(self, name: str, with_decryption: bool = True) -> Optional[str]:
        """Get a single parameter from SSM Parameter Store."""
        try:
            response = self.client.get_parameter(
                Name=name,
                WithDecryption=with_decryption
            )
            return response['Parameter']['Value']
        except ClientError as e:
            if e.response['Error']['Code'] == 'ParameterNotFound':
                logger.warning(f"Parameter {name} not found")
                return None
            logger.error(f"Error getting parameter {name}: {e}")
            raise
    
    def list_all_parameters(self) -> List[Dict[str, str]]:
        """List all parameters in AWS Parameter Store."""
        try:
            parameters = []
            paginator = self.client.get_paginator('describe_parameters')
            
            for page in paginator.paginate():
                for param in page.get('Parameters', []):
                    parameters.append({
                        "name": param['Name'],
                        "type": param['Type'],
                        "last_modified": param['LastModifiedDate'].isoformat(),
                    })
            
            return parameters
        except ClientError as e:
            logger.error(f"Error listing parameters: {e}")
            raise


# Singleton instances
s3_client = S3Client()
ssm_client = SSMClient()
