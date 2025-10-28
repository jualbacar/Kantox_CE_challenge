# Kantox Cloud Engineer Challenge - Application

This directory contains the Python FastAPI microservices for the Kantox Cloud Engineer technical challenge.

## Architecture

Two microservices with different IAM permissions:

### 1. **API Service** (api namespace)
- **IAM Permissions**: S3 (list buckets) + SSM Parameter Store (read)
- **Endpoints**:
  - `GET /health` - Health check
  - `GET /config` - List all SSM parameters
  - `GET /config/{parameter_name}` - Get specific parameter value
  - `GET /storage` - List all S3 buckets in AWS account

### 2. **Auxiliary Service** (aux namespace)
- **IAM Permissions**: SSM Parameter Store (read only) - **NO S3 ACCESS**
- **Endpoints**:
  - `GET /health` - Health check
  - `GET /config` - List all SSM parameters
  - `GET /config/{parameter_name}` - Get specific parameter value

## Project Structure

```
app/
├── Dockerfile                    # Multi-stage, reusable for both services
├── .dockerignore                # Docker build exclusions
├── requirements.txt              # Shared Python dependencies
├── README.md                    # This file
│
├── common/                      # Shared code between services
│   ├── __init__.py
│   ├── aws_client.py           # AWS SDK wrappers (S3 + SSM)
│   └── config.py               # Configuration management
│
├── api/                        # Main API service (S3 + SSM)
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry point
│   └── routers/
│       ├── health.py           # Health check endpoint
│       ├── config.py           # SSM Parameter Store endpoints
│       └── storage.py          # S3 list buckets endpoint
│
└── aux/                        # Auxiliary service (SSM only)
    ├── __init__.py
    ├── main.py                 # FastAPI app entry point
    └── routers/
        ├── health.py           # Health check endpoint
        └── config.py           # SSM Parameter Store endpoints
```

## Building Docker Images

The same Dockerfile builds both services using the `SERVICE` build argument:

### Build API Service
```bash
docker build --build-arg SERVICE=api -t kantox-api:latest .
```

### Build Auxiliary Service
```bash
docker build --build-arg SERVICE=aux -t kantox-aux:latest .
```

## Running Locally

### Prerequisites
- Python 3.11+
- AWS credentials configured
- Required environment variables

### Environment Variables

```bash
# Service identification
export SERVICE_NAME=api                      # or "aux"
export ENVIRONMENT=dev                       # dev, qa, prod
export AWS_REGION=eu-west-1

# Optional
export LOG_LEVEL=INFO
```

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run API Service

```bash
export SERVICE_NAME=api
export PYTHONPATH=$PWD
uvicorn api.main:app --host 0.0.0.0 --port 8080 --reload
```

Access at: http://localhost:8080
- Docs: http://localhost:8080/docs
- Health: http://localhost:8080/health

### Run Auxiliary Service

```bash
export SERVICE_NAME=aux
export PYTHONPATH=$PWD
uvicorn aux.main:app --host 0.0.0.0 --port 8081 --reload
```

Access at: http://localhost:8081
- Docs: http://localhost:8081/docs
- Health: http://localhost:8081/health

## Running with Docker

### API Service
```bash
docker run -d \
  --name kantox-api \
  -p 8080:8080 \
  -e SERVICE_NAME=api \
  -e ENVIRONMENT=dev \
  -e AWS_REGION=eu-west-1 \
  -e AWS_ACCESS_KEY_ID=your_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret \
  kantox-api:latest
```

### Auxiliary Service
```bash
docker run -d \
  --name kantox-aux \
  -p 8081:8080 \
  -e SERVICE_NAME=aux \
  -e ENVIRONMENT=dev \
  -e AWS_REGION=eu-west-1 \
  -e AWS_ACCESS_KEY_ID=your_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret \
  kantox-aux:latest
```

## API Examples

### Health Check
```bash
curl http://localhost:8080/health
```

### List All SSM Parameters
```bash
curl http://localhost:8080/config
```

### Get Specific Parameter Value
```bash
# Using full parameter path
curl http://localhost:8080/config//kantox/dev/database/host

# Or just the parameter name if it's at root level
curl http://localhost:8080/config/my-parameter
```

### List All S3 Buckets (API service only)
```bash
# List all S3 buckets in the AWS account
curl http://localhost:8080/storage
```

## Deployment to Kubernetes

See the `kubernetes/` directory for deployment manifests that integrate with:
- IAM roles created by Terraform
- Service accounts with IRSA annotations
- ConfigMaps for environment-specific configuration

## Key Design Decisions

1. **Single Dockerfile**: Uses `ARG SERVICE` to build both services, reducing duplication
2. **Shared Common Module**: AWS clients and config logic reused by both services
3. **IAM-Aware Design**: Auxiliary service deliberately excludes S3 endpoints to respect IAM restrictions
4. **Simplified API**: 
   - S3: Lists all buckets in AWS account (no object-level operations)
   - SSM: Two operations only - list all parameters, get specific parameter value
5. **Environment-Based Config**: All configuration via environment variables (12-factor app)
6. **Health Checks**: Built-in liveness/readiness probes for Kubernetes
7. **FastAPI**: Automatic OpenAPI docs, type validation, async support

## Technology Stack

- **Framework**: FastAPI 0.104.1
- **Server**: Uvicorn with standard extras
- **AWS SDK**: boto3 1.29.7
- **Validation**: Pydantic 2.5.0
- **Python**: 3.11

## Notes

- Import errors in the editor are expected until dependencies are installed
- The auxiliary service will return errors if attempting to access S3 (by design)
- Both services use the same base configuration but expose different capabilities
- Container health checks use the `/health` endpoint
