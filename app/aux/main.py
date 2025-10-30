"""FastAPI application for Auxiliary service."""
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from common.config import settings
from common.version import router as version_router
from aux.routers import health, parameters, s3

logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Kantox Auxiliary Service",
    description="Internal service handling AWS operations (S3 + SSM)",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, tags=["health"])
app.include_router(parameters.router, tags=["parameters"])
app.include_router(s3.router, tags=["s3"])
app.include_router(version_router)


@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {settings.service_name} service")
    logger.info(f"Environment: {settings.environment}")
    logger.info(f"AWS Region: {settings.aws_region}")
    logger.info("Internal service - handles all AWS operations (S3 + SSM)")


@app.get("/")
async def root():
    return {
        "service": "Kantox Auxiliary Service",
        "version": "2.0.0",
        "environment": settings.environment,
        "type": "internal",
        "capabilities": ["s3_operations", "parameter_store"],
        "endpoints": {
            "health": "/health",
            "s3_buckets": "/s3/buckets",
            "parameters": "/parameters",
            "parameters_get": "/parameters/{name}",
            "version": "/version",
            "docs": "/docs",
        }
    }
