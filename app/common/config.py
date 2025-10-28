"""Configuration management for the application."""
import os


class Settings:
    """Application settings from environment variables."""
    
    def __init__(self):
        self.service_name: str = os.getenv("SERVICE_NAME", "unknown")
        self.aws_region: str = os.getenv("AWS_REGION", "eu-west-1")
        self.environment: str = os.getenv("ENVIRONMENT", "dev")
        self.log_level: str = os.getenv("LOG_LEVEL", "INFO")


# Global settings instance
settings = Settings()
