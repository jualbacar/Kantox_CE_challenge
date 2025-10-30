# Kantox Application Services

Backend for Frontend (BFF) architecture with two Python FastAPI microservices implementing API Gateway pattern and security through service isolation.

## Architecture: Backend for Frontend (BFF)

This application uses a **BFF/API Gateway pattern** where:

- **API Service** acts as a **public gateway** - orchestrates requests, no direct AWS access
- **AUX Service** acts as the **internal backend** - handles all AWS operations (S3 + SSM)

### Benefits of This Architecture:
- **Security**: Only internal service has AWS credentials, reducing attack surface
- **Separation of Concerns**: Gateway handles routing/orchestration, backend handles AWS operations
- **Scalability**: Services can scale independently based on workload
- **Flexibility**: Easy to add new backends or modify AWS access without touching gateway

## Services

### API Service (port 8080) - Public Gateway
**Namespace**: `api`  
**IAM Permissions**: None - no direct AWS access  
**Replicas**: 2  
**Communication**: HTTP to AUX service via Kubernetes DNS

**Endpoints**:
- `GET /health` - Health check with service info
- `GET /storage` - Proxy to AUX service for S3 buckets
- `GET /config` - Proxy to AUX service for SSM parameters
- `GET /config/{parameter_name}` - Proxy to AUX service for specific parameter
- `GET /docs` - OpenAPI documentation

### AUX Service (port 8080) - Internal Backend
**Namespace**: `aux`  
**IAM Permissions**: S3 + SSM Parameter Store (full AWS access)  
**Replicas**: 1  
**Access**: Internal only (ClusterIP service)

**Endpoints**:
- `GET /health` - Health check with service info
- `GET /s3/buckets` - List all S3 buckets in AWS account
- `GET /parameters` - List all SSM parameters
- `GET /parameters/{parameter_name}` - Get specific SSM parameter value
- `GET /docs` - OpenAPI documentation

## Request Flow

```
External Request → API Gateway → AUX Service → AWS
                 (no AWS creds)  (has AWS creds)
```

1. **Client** makes request to API service (e.g., `GET /storage`)
2. **API Service** proxies request to AUX service via HTTP (`aux.aux.svc.cluster.local:80`)
3. **AUX Service** uses IAM role to access AWS resources (S3/SSM)
4. **AUX Service** returns data to API service
5. **API Service** returns response to client

## AWS Access Pattern (AUX Service Only)

Only the **AUX service** uses **IAM role assumption** for AWS access:

1. **Base Credentials**: AUX pod starts with minimal IAM user credentials
   - Can only assume the AUX service role
   - Injected via Kubernetes secret

2. **Role Assumption**: Application checks for `AWS_ROLE_ARN` environment variable
   - Uses base credentials to call STS AssumeRole
   - Gets temporary credentials with full permissions
   - Temporary credentials are cached in memory

3. **AWS Operations**: All AWS SDK calls use the temporary credentials
   - S3 operations (list buckets)
   - SSM Parameter Store operations (list/get parameters)

**API Service**: No AWS credentials or SDK - uses HTTP client (httpx) to communicate with AUX service.

```
app/
├── Dockerfile                    # Multi-stage, reusable for both services
├── .dockerignore                # Docker build exclusions
├── requirements.txt              # Shared Python dependencies
├── README.md                    # This file
│
├── common/                      # Shared code between services
│   ├── __init__.py
│   ├── aws_client.py           # AWS SDK wrappers (S3 + SSM) - used by AUX only
│   ├── config.py               # Configuration management
│   └── version.py              # Application version
│
├── api/                        # API Gateway service (no AWS access)
│   ├── __init__.py
│   ├── main.py                 # FastAPI app entry point
│   ├── aux_client.py           # HTTP client for AUX service communication
│   └── routers/
│       ├── health.py           # Health check endpoint
│       ├── config.py           # SSM endpoints (proxy to AUX)
│       └── storage.py          # S3 endpoints (proxy to AUX)
│
└── aux/                        # Backend service (full AWS access)
    ├── __init__.py
    ├── main.py                 # FastAPI app entry point
    └── routers/
        ├── health.py           # Health check endpoint
        ├── parameters.py       # SSM Parameter Store endpoints
        └── s3.py               # S3 operations endpoints
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

#### API Service (Gateway)
```bash
# Required - Service identification
export SERVICE_NAME=api
export ENVIRONMENT=dev                       # dev, qa, prod

# Required - AUX service URL
export AUX_SERVICE_URL=http://aux.aux.svc.cluster.local:80

# Optional
export LOG_LEVEL=INFO                        # DEBUG, INFO, WARNING, ERROR
```

#### AUX Service (Backend)
```bash
# Required - Service identification
export SERVICE_NAME=aux
export ENVIRONMENT=dev                       # dev, qa, prod
export AWS_REGION=eu-west-1

# Required - AWS Credentials
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_ROLE_ARN=<role-arn-to-assume>    # AUX service role ARN

# Optional
export LOG_LEVEL=INFO                        # DEBUG, INFO, WARNING, ERROR
```

The AUX service will automatically assume the role specified in `AWS_ROLE_ARN` using the base credentials.

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run AUX Service (Backend - must start first)

```bash
export SERVICE_NAME=aux
export AWS_REGION=eu-west-1
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_ROLE_ARN=<aux-role-arn>
export PYTHONPATH=$PWD
uvicorn aux.main:app --host 0.0.0.0 --port 8081 --reload
```

Access at: http://localhost:8081
- Docs: http://localhost:8081/docs
- Health: http://localhost:8081/health
- S3 Buckets: http://localhost:8081/s3/buckets
- Parameters: http://localhost:8081/parameters

### Run API Service (Gateway)

```bash
export SERVICE_NAME=api
export AUX_SERVICE_URL=http://localhost:8081  # Point to local AUX service
export PYTHONPATH=$PWD
uvicorn api.main:app --host 0.0.0.0 --port 8080 --reload
```

Access at: http://localhost:8080
- Docs: http://localhost:8080/docs
- Health: http://localhost:8080/health
- Storage: http://localhost:8080/storage (proxies to AUX)
- Config: http://localhost:8080/config (proxies to AUX)

## Running with Docker

### Auxiliary Service (Backend - start first)
```bash
docker run -d \
  --name kantox-aux \
  -p 8081:8080 \
  -e SERVICE_NAME=aux \
  -e ENVIRONMENT=dev \
  -e AWS_REGION=eu-west-1 \
  -e AWS_ACCESS_KEY_ID=your_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret \
  -e AWS_ROLE_ARN=arn:aws:iam::xxx:role/kantox-aux-role-dev \
  kantox-aux:latest
```

### API Service (Gateway - needs AUX service running)
```bash
docker run -d \
  --name kantox-api \
  -p 8080:8080 \
  --link kantox-aux:aux \
  -e SERVICE_NAME=api \
  -e ENVIRONMENT=dev \
  -e AUX_SERVICE_URL=http://aux:8080 \
  kantox-api:latest
```

Note: The `--link` flag connects the API container to the AUX container. In Kubernetes, this is handled automatically via service discovery.

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

### List All S3 Buckets
```bash
# Via API Gateway (proxies to AUX)
curl http://localhost:8080/storage

# Or directly to AUX service (internal)
curl http://localhost:8081/s3/buckets
```

## Deployment to Kubernetes

Both services are deployed via ArgoCD with GitOps practices:

### Deployment Configuration

**API Service (Gateway)**:
- **Image Pull**: Uses ECR registry secrets
- **AWS Credentials**: None - no AWS access required
- **Service Discovery**: Connects to AUX via `AUX_SERVICE_URL` environment variable
- **Security Context**: Runs as non-root user (UID 1000)
- **Health Checks**: Liveness and readiness probes on `/health`
- **Resources**: CPU and memory limits defined
- **Replicas**: 2 (can scale independently)

**AUX Service (Backend)**:
- **Image Pull**: Uses ECR registry secrets
- **AWS Credentials**: Injected via Kubernetes secret
- **Role ARN**: Set via environment variables in deployment
- **Security Context**: Runs as non-root user (UID 1000)
- **Health Checks**: Liveness and readiness probes on `/health`
- **Resources**: CPU and memory limits defined
- **Replicas**: 1 (internal service)
- **Service Type**: ClusterIP (internal only, not exposed externally)

### Kubernetes Resources

**API Namespace**:
- Namespace: `api`
- Deployment: 2 replicas
- Service: ClusterIP on port 80
- ConfigMap: Environment configuration
- Secret: ECR registry credentials only

**AUX Namespace**:
- Namespace: `aux`
- Deployment: 1 replica
- Service: ClusterIP on port 80 (internal only)
- ConfigMap: Environment configuration
- Secret: AWS credentials + ECR registry credentials

See `../kubernetes/` directory for complete manifests.

## Key Design Decisions

1. **BFF/API Gateway Pattern**: Separates public gateway from backend operations for security and scalability
2. **No AWS Access in Gateway**: API service has zero AWS credentials, reducing attack surface
3. **Service-to-Service HTTP**: API communicates with AUX via async HTTP (httpx library)
4. **IAM Role Assumption**: AUX service assumes IAM role for AWS access (temporary credentials)
5. **Single Dockerfile**: Uses `ARG SERVICE` to build both services, reducing duplication
6. **Shared Common Module**: AWS clients and config logic reused (AUX service only)
7. **Non-Root Security**: Containers run as UID 1000 for better security posture
8. **Kubernetes Service Discovery**: API finds AUX via DNS (`aux.aux.svc.cluster.local`)
9. **Environment-Based Config**: All configuration via environment variables (12-factor app)
10. **Health Checks**: Built-in `/health` endpoint for Kubernetes liveness and readiness probes
11. **FastAPI**: Provides automatic OpenAPI docs, type validation, and async support

## Technology Stack

- **Framework**: FastAPI 0.115.0
- **Server**: Uvicorn with standard extras
- **HTTP Client**: httpx 0.27.0 (for service-to-service communication)
- **AWS SDK**: boto3 1.35.0 (AUX service only)
- **Validation**: Pydantic 2.10.0
- **Python**: 3.14

## Notes

- **Architecture**: BFF pattern with API as gateway, AUX as backend - only AUX has AWS access
- **Service Communication**: API → AUX via HTTP (async httpx client with connection pooling)
- **IAM Role Assumption**: Only AUX service assumes IAM role for AWS operations
- **Endpoint Mapping**: 
  - API `/storage` → AUX `/s3/buckets`
  - API `/config` → AUX `/parameters`
  - API `/config/{name}` → AUX `/parameters/{name}`
- **Security**: Zero AWS credentials in API service reduces security risk
- **Error Handling**: HTTP errors from AUX are propagated to API clients with proper status codes
- **Container Health**: Both services use `/health` endpoint for Kubernetes probes
- **CI/CD**: Images automatically built and pushed by GitHub Actions on commits to main branch
- **Versioning**: Both services currently at v2.0.0 (BFF architecture)
