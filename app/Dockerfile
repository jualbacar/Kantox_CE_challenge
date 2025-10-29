# Multi-stage build for smaller final image
# Stage 1: Build dependencies
# Using Python 3.12 slim image
FROM python:3.12-slim AS builder

WORKDIR /app

# Install build dependencies and CA certificates
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM python:3.12-slim

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Copy common shared code
COPY common/ ./common/

# Build argument to determine which service to run
ARG SERVICE=api

# Copy specific service code
COPY ${SERVICE}/ ./${SERVICE}/

# Set environment variables
ENV SERVICE_NAME=${SERVICE}
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"]

# Run the application
CMD ["sh", "-c", "uvicorn ${SERVICE_NAME}.main:app --host 0.0.0.0 --port 8080"]
