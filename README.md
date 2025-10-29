# Kantox Cloud Engineer Challenge

A cloud-native solution demonstrating Kubernetes deployment with CI/CD, AWS integration, and GitOps practices using Python FastAPI microservices.

## Architecture Overview

Two Python FastAPI microservices deployed on Kubernetes:

- **API Service** - S3 + SSM access, 2 replicas
- **Auxiliary Service** - SSM access only, 1 replica

**Technology Stack:**
- **Application**: Python 3.14, FastAPI
- **Infrastructure**: Terraform, AWS (S3, SSM, ECR, IAM)
- **Orchestration**: Kubernetes (Minikube)
- **CI/CD**: GitHub Actions (OIDC authentication)
- **GitOps**: ArgoCD

## Prerequisites

- Docker Desktop or Docker Engine
- Minikube
- kubectl
- AWS CLI configured with credentials
- Terraform >= 1.5.0
- Git

## Quick Start

### 1. Deploy AWS Infrastructure

```bash
cd infrastructure
terraform init
terraform workspace new dev
terraform apply -var-file=eu-west-1/dev/dev.tfvars
```

📚 **See**: [Infrastructure Documentation](infrastructure/README.md)

### 2. Setup Kubernetes

```bash
# Start Minikube
minikube start --cpus=4 --memory=8192

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

📚 **See**: [ArgoCD Setup Guide](kubernetes/argocd/README.md)

### 3. Configure Secrets

```bash
# Generate AWS credentials secrets
bash scripts/setup-k8s-secrets.sh

# Apply secrets
kubectl apply -f infrastructure/kubernetes/api-aws-credentials-secret.yaml
kubectl apply -f infrastructure/kubernetes/aux-aws-credentials-secret.yaml

# Create ECR pull secrets (replace <account-id> with your AWS account ID)
ECR_PASSWORD=$(aws ecr get-login-password --region eu-west-1)
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=<account-id>.dkr.ecr.eu-west-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --namespace=api

kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=<account-id>.dkr.ecr.eu-west-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --namespace=aux
```

### 4. Deploy Applications

```bash
# Deploy via ArgoCD
kubectl apply -f kubernetes/argocd/api-application.yaml
kubectl apply -f kubernetes/argocd/aux-application.yaml
```

ArgoCD will automatically sync and deploy both services.

### 5. Access Services

```bash
# Port-forward to API service
kubectl port-forward -n api service/api 8080:80

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/storage
curl http://localhost:8080/docs
```

## Documentation

### Component Guides

| Component | Documentation | Description |
|-----------|--------------|-------------|
| **Application** | [app/README.md](app/README.md) | FastAPI services, local development, Docker |
| **Infrastructure** | [infrastructure/README.md](infrastructure/README.md) | Terraform configuration, AWS resources |
| **CI/CD Pipeline** | [.github/README.md](.github/README.md) | GitHub Actions workflow, automated builds |
| **GitHub OIDC** | [infrastructure/GITHUB_OIDC_SETUP.md](infrastructure/GITHUB_OIDC_SETUP.md) | AWS authentication setup for CI/CD |
| **Kubernetes/ArgoCD** | [kubernetes/argocd/README.md](kubernetes/argocd/README.md) | GitOps deployment, ArgoCD setup |

### Additional Documentation

- [app/API_CHANGES.md](app/API_CHANGES.md) - API changes and migration guide
- [app/PYTHON_UPGRADE.md](app/PYTHON_UPGRADE.md) - Python 3.14 compatibility notes

## Security Features

- Non-root containers (UID 1000)
- IAM role assumption for least privilege access
- ECR image pull secrets for private registries
- Kubernetes secrets for AWS credentials
- GitHub OIDC for CI/CD (no static credentials)
- Read-only root filesystem options

## CI/CD Pipeline

GitHub Actions automatically:
1. Builds Docker images on push to main
2. Tags images with commit SHA
3. Pushes to AWS ECR
4. Updates Kubernetes manifests
5. ArgoCD syncs changes automatically

📚 **See**: [CI/CD Pipeline Documentation](.github/README.md) for detailed workflow explanation

**Workflow file**: [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml)

## Monitoring

```bash
# Check pod status
kubectl get pods -n api
kubectl get pods -n aux

# View logs
kubectl logs -n api -l app=api
kubectl logs -n aux -l app=aux

# ArgoCD sync status
kubectl get applications -n argocd
```

## Troubleshooting

### Pods stuck in ImagePullBackOff
- Verify ECR pull secrets are created in both namespaces
- Check AWS credentials are valid
- Ensure images exist in ECR with correct tags

### AWS Access Denied errors
- Verify Kubernetes secrets are applied correctly
- Check IAM role ARNs in deployment environment variables
- Ensure base IAM user can assume the service roles

### ArgoCD not syncing
- Check GitHub repository access
- Verify application manifests are valid
- Look at ArgoCD application events: `kubectl describe application api -n argocd`

## Clean Up

```bash
# Delete ArgoCD applications
kubectl delete -f kubernetes/argocd/

# Delete namespaces
kubectl delete namespace api aux argocd

# Destroy AWS infrastructure
cd infrastructure
terraform destroy -var-file=eu-west-1/dev/dev.tfvars

# Stop Minikube
minikube stop
```

## Project Structure

```
.
├── .github/workflows/       # GitHub Actions CI/CD
├── app/                     # Python FastAPI applications
│   ├── api/                # API service (S3 + SSM)
│   ├── aux/                # Auxiliary service (SSM only)
│   ├── common/             # Shared AWS clients
│   └── README.md           # 📖 Application documentation
├── infrastructure/          # Terraform AWS resources
│   ├── *.tf               # Terraform configuration
│   ├── eu-west-1/         # Region-specific variables
│   ├── README.md          # 📖 Infrastructure documentation
│   └── GITHUB_OIDC_SETUP.md # 📖 CI/CD setup guide
├── kubernetes/             # Kubernetes manifests
│   ├── api/               # API deployment
│   ├── aux/               # AUX deployment
│   └── argocd/            # ArgoCD applications
│       └── README.md      # 📖 ArgoCD setup guide
└── scripts/               # Helper scripts
```

## License

See [LICENSE](LICENSE) file for details.
