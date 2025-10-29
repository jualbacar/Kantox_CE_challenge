"""FastAPI application for Auxiliary service."""
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from common.config import settings
from common.version import router as version_router
from aux.routers import health, config

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Kantox Auxiliary Service",
    description="Auxiliary service with SSM Parameter Store access only",
    version="1.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers (no storage router - respects IAM permissions)
app.include_router(health.router, tags=["health"])
app.include_router(config.router, tags=["config"])
app.include_router(version_router)


@app.on_event("startup")
async def startup_event():
    """Log startup information."""
    logger.info(f"Starting {settings.service_name} service")
    logger.info(f"Environment: {settings.environment}")
    logger.info(f"AWS Region: {settings.aws_region}")
    logger.info("Note: This service has NO S3 access (respects IAM role restrictions)")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "Kantox Auxiliary Service",
        "version": "1.0.0",
        "environment": settings.environment,
        "capabilities": ["config_read"],
        "endpoints": {
            "health": "/health",
            "config": "/config",
            "version": "/version",
            "docs": "/docs",
        }
    }
