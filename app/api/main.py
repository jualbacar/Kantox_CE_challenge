"""FastAPI application for API service."""
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from common.config import settings
from common.version import router as version_router
from api.routers import health, config, storage

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Kantox API Service",
    description="API service with S3 and SSM Parameter Store access",
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

# Include routers
app.include_router(health.router, tags=["health"])
app.include_router(config.router, tags=["config"])
app.include_router(storage.router, tags=["storage"])
app.include_router(version_router)


@app.on_event("startup")
async def startup_event():
    """Log startup information."""
    logger.info(f"Starting {settings.service_name} service")
    logger.info(f"Environment: {settings.environment}")
    logger.info(f"AWS Region: {settings.aws_region}")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "Kantox API Service",
        "version": "1.0.0",
        "environment": settings.environment,
        "endpoints": {
            "health": "/health",
            "config": "/config",
            "storage": "/storage",
            "version": "/version",
            "docs": "/docs",
        }
    }
