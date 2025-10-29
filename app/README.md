# Kantox Application Services

Two Python FastAPI microservices with different IAM permissions demonstrating least privilege access patterns.

## Services

### API Service (port 8080)
**Namespace**: `api`  
**IAM Permissions**: S3 + SSM Parameter Store  
**Replicas**: 2

**Endpoints**:
- `GET /health` - Health check with service info
- `GET /storage` - List all S3 buckets in AWS account
- `GET /config` - List all SSM parameters
- `GET /config/{parameter_name}` - Get specific SSM parameter value
- `GET /docs` - OpenAPI documentation

### Auxiliary Service (port 8080)
**Namespace**: `aux`  
**IAM Permissions**: SSM Parameter Store only (no S3 access)  
**Replicas**: 1

**Endpoints**:
- `GET /health` - Health check with service info
- `GET /config` - List all SSM parameters
- `GET /config/{parameter_name}` - Get specific SSM parameter value
- `GET /docs` - OpenAPI documentation

## AWS Access Pattern

Both services use **IAM role assumption** for AWS access:

1. **Base Credentials**: Pods start with minimal IAM user credentials
   - Can only assume service-specific roles
   - Injected via Kubernetes secrets

2. **Role Assumption**: Application checks for `AWS_ROLE_ARN` environment variable
   - Uses base credentials to call STS AssumeRole
   - Gets temporary credentials with full permissions
   - Temporary credentials are cached in memory

3. **AWS Operations**: All AWS SDK calls use the temporary credentials
   - S3 operations (API service only)
   - SSM Parameter Store operations (both services)

This pattern follows AWS security best practices for least privilege access.

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

The Dockerfile builds both services and runs as a non-root user (UID 1000) for security.

### Build API Service
```bash
docker build --build-arg SERVICE=api -t kantox-api:latest .
```

### Build Auxiliary Service
```bash
docker build --build-arg SERVICE=aux -t kantox-aux:latest .
```

### Push to ECR
```bash
# Login to ECR
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-1.amazonaws.com

# Tag and push
docker tag kantox-api:latest <account-id>.dkr.ecr.eu-west-1.amazonaws.com/kantox-api:latest
docker push <account-id>.dkr.ecr.eu-west-1.amazonaws.com/kantox-api:latest
```

Note: In production, GitHub Actions handles building and pushing images automatically.

## Running Locally

### Prerequisites
- Python 3.14+
- AWS credentials configured
- Required environment variables

### Environment Variables

```bash
# Required - Service identification
export SERVICE_NAME=api                      # or "aux"
export ENVIRONMENT=dev                       # dev, qa, prod
export AWS_REGION=eu-west-1

# Required - AWS Credentials
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_ROLE_ARN=<role-arn-to-assume>    # Service-specific role ARN

# Optional
export LOG_LEVEL=INFO                        # DEBUG, INFO, WARNING, ERROR
```

The application will automatically assume the role specified in `AWS_ROLE_ARN` using the base credentials.

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

Both services are deployed via ArgoCD with GitOps practices:

### Deployment Configuration
- **Image Pull**: Uses ECR registry secrets
- **AWS Credentials**: Injected via Kubernetes secrets
- **Role ARN**: Set via environment variables in deployments
- **Security Context**: Runs as non-root user (UID 1000)
- **Health Checks**: Liveness and readiness probes on `/health`
- **Resources**: CPU and memory limits defined

### Kubernetes Resources
- Namespace: `api` or `aux`
- Deployment: 2 replicas (API), 1 replica (AUX)
- Service: ClusterIP on port 80
- ConfigMap: Environment-specific configuration
- Secret: AWS credentials for role assumption

See `../kubernetes/` directory for complete manifests.

## Key Design Decisions

1. **IAM Role Assumption**: Services assume IAM roles for AWS access instead of using long-lived credentials
2. **Single Dockerfile**: Uses `ARG SERVICE` to build both services, reducing duplication
3. **Shared Common Module**: AWS clients and config logic reused by both services
4. **Non-Root Security**: Containers run as UID 1000 for better security posture
5. **Service Separation**: Auxiliary service excludes S3 endpoints to respect IAM restrictions
6. **Environment-Based Config**: All configuration via environment variables (12-factor app)
7. **Health Checks**: Built-in `/health` endpoint for Kubernetes liveness and readiness probes
8. **FastAPI**: Provides automatic OpenAPI docs, type validation, and async support

## Technology Stack

- **Framework**: FastAPI 0.104.1
- **Server**: Uvicorn with standard extras
- **AWS SDK**: boto3 1.29.7
- **Validation**: Pydantic 2.5.0
- **Python**: 3.14

## Notes

- Services automatically assume IAM roles if `AWS_ROLE_ARN` is set
- The auxiliary service will return errors if attempting to access S3 (by design - no permissions)
- Both services use the same base configuration but expose different capabilities based on IAM permissions
- Container health checks use the `/health` endpoint for Kubernetes probes
- Images are automatically built and pushed by GitHub Actions on commits to main branch
