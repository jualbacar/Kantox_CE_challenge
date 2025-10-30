# Kantox Cloud Engineer Challenge

A cloud-native solution demonstrating Kubernetes deployment with CI/CD, AWS integration, and GitOps practices using Python FastAPI microservices.

## Architecture Overview

**Backend for Frontend (BFF) / API Gateway Pattern**

Two Python FastAPI microservices implementing modern cloud architecture:

- **API Service** - Public gateway (no AWS access), 2 replicas
- **AUX Service** - Internal backend (S3 + SSM access), 1 replica

### Architecture Benefits:
- **Security**: Only internal service has AWS credentials, minimizing attack surface
- **Scalability**: Services scale independently based on workload
- **Separation of Concerns**: Gateway handles routing, backend handles AWS operations
- **Service Isolation**: Failures in backend don't expose credentials

**Technology Stack:**
- **Application**: Python 3.14, FastAPI, httpx
- **Infrastructure**: Terraform, AWS (S3, SSM, ECR, IAM)
- **Orchestration**: Kubernetes (Minikube)
- **CI/CD**: GitHub Actions (OIDC authentication)
- **GitOps**: ArgoCD

## Prerequisites

- Docker, Minikube, kubectl
- AWS CLI with credentials configured (`aws configure`)
- Terraform >= 1.5.0

## Quick Start

### 1. Deploy AWS Infrastructure (don't forget about the AWS credentials setup)

```bash
cd infrastructure
terraform init                    # (one-time setup)
terraform workspace new dev       # (one-time setup)
terraform apply -var-file=eu-west-1/dev/dev.tfvars
```

📚 **See**: [Infrastructure Documentation](infrastructure/README.md)

### 2. Build Initial Docker Images (first time setup)

After deploying infrastructure, trigger the CI/CD pipeline to build and push initial images to ECR:

**On GitHub UI**
1. Go to the [Actions tab](../../actions) in GitHub
2. Select "CI/CD Pipeline" workflow
3. Click "Run workflow" → "Run workflow"
4. Wait for completion (~2-3 minutes)

This step is required on the first deployment as ECR repositories are initially empty.

### 3. Setup Kubernetes (first time setup)

```bash
# Start Minikube
minikube start

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

📚 **See**: [ArgoCD Setup Guide](kubernetes/argocd/README.md)

### 4. Configure Secrets (first time setup)

```bash
# Generate AWS credentials secret (for AUX service only)
bash ./scripts/setup-k8s-secrets.sh (from root folder)

# Create microservices namespaces
kubectl create namespace api
kubectl create namespace aux

# Apply secret
kubectl apply -f kubernetes/aux-aws-credentials-secret.yaml

# Note: ECR authentication tokens expire after 12 hours, requiring periodic refresh.
# Create ECR pull secrets (replace <account-id> with your AWS account ID)
bash ./scripts/refresh-ecr-credentials.sh (from root folder)
```

### 5. Deploy Applications

```bash
# Deploy via ArgoCD
kubectl apply -f kubernetes/argocd/api-application.yaml
kubectl apply -f kubernetes/argocd/aux-application.yaml
```

ArgoCD will automatically sync and deploy both services.

### 6. Access Services

```bash
# Port-forward to API service
kubectl port-forward -n api service/api 8080:80 > /dev/null 2>&1 &

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/storage
curl http://localhost:8080/docs
```

### Testing Continuous Deployment

To test the full CI/CD pipeline and see automatic deployments in action:

```bash
# Make a small change to any file in app/ directory
echo "# Test change" >> app/README.md

# Commit and push to main branch
git add app/README.md
git commit -m "test: trigger CI/CD pipeline"
git push
```

The workflow will automatically build new images, push them to ECR, and ArgoCD will sync the updated deployments to your cluster. Monitor progress in the [GitHub Actions tab](../../actions).

## Documentation

### Component Guides

| Component | Documentation | Description |
|-----------|--------------|-------------|
| **Application** | [app/README.md](app/README.md) | FastAPI services, local development, Docker |
| **Infrastructure** | [infrastructure/README.md](infrastructure/README.md) | Terraform configuration, AWS resources |
| **CI/CD Pipeline** | [.github/README.md](.github/README.md) | GitHub Actions workflow, automated builds |
| **GitHub OIDC** | [infrastructure/GITHUB_OIDC_SETUP.md](infrastructure/GITHUB_OIDC_SETUP.md) | AWS authentication setup for CI/CD |
| **Kubernetes/ArgoCD** | [kubernetes/argocd/README.md](kubernetes/argocd/README.md) | GitOps deployment, ArgoCD setup |

## Security Features

- **BFF Architecture**: Only internal service has AWS access (reduced attack surface)
- **Service Isolation**: API gateway has zero AWS credentials
- **Non-root Containers**: All pods run as UID 1000
- **IAM Role Assumption**: AUX service uses temporary credentials via STS
- **Least Privilege**: Base IAM user can only assume service role
- **ECR Image Pull Secrets**: Private registry authentication
- **Kubernetes Secrets**: Credentials never committed to git
- **GitHub OIDC**: CI/CD without static credentials
- **Internal Service**: AUX service not exposed externally (ClusterIP only)

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

### Pods stuck in ImagePullBackOff or "authorization token has expired"
ECR authentication tokens expire after 12 hours. Use the provided script to refresh credentials:

```bash
# Run the ECR credentials refresh script
bash scripts/refresh-ecr-credentials.sh
```

The script will:
- Obtain a fresh ECR authentication token from AWS
- Update secrets in both `api` and `aux` namespaces
- Restart deployments to pick up the new credentials
- Provide status updates throughout the process

### Corporate proxy/SSL certificate issues
If images fail to pull due to certificate errors (e.g., ArgoCD dex image), pull the image locally and load it into minikube:

```bash
# Pull image using host Docker (which trusts corporate CA)
docker pull ghcr.io/dexidp/dex:v2.43.0

# Load into minikube
minikube image load ghcr.io/dexidp/dex:v2.43.0

# Patch deployment to use local image
kubectl patch deployment argocd-dex-server -n argocd -p '{"spec":{"template":{"spec":{"containers":[{"name":"dex","imagePullPolicy":"IfNotPresent"}]}}}}'
```

### AWS Access Denied errors
- Verify Kubernetes secrets are applied correctly
- Check IAM role ARNs in deployment environment variables
- Ensure base IAM user can assume the service roles

### ArgoCD not syncing
- Check GitHub repository access
- Verify application manifests are valid
- Look at ArgoCD application events: `kubectl describe application api -n argocd`

### Git push rejected (branch behind origin)
The CI/CD workflow automatically updates Kubernetes manifest files (image tags) and pushes them back to the repository. This can cause your local branch to be behind origin when you try to push.

**Solution:**
```bash
# Pull the latest changes with rebase
git pull --rebase

# Then push your changes
git push
```

**Note**: The workflow updates `kubernetes/api/deployment.yaml` and `kubernetes/aux/deployment.yaml` with new image tags after each successful build.

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
