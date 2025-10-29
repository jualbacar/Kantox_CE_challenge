# ArgoCD Setup & Configuration Guide

Complete guide for deploying applications using ArgoCD on Kubernetes (Minikube).

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Install ArgoCD](#install-argocd)
3. [Access ArgoCD UI](#access-argocd-ui)
4. [Deploy Applications](#deploy-applications)
5. [Application Configuration](#application-configuration)
6. [Troubleshooting](#troubleshooting)
7. [Corporate Proxy Setup](#corporate-proxy-setup)

## Prerequisites

- Minikube installed and running
- kubectl configured
- Docker Desktop installed
- Git repository with Kubernetes manifests

## Install ArgoCD

### 1. Start Minikube

```bash
minikube start --cpus=4 --memory=8192
```

### 2. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD components
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

Verify installation:

```bash
kubectl get pods -n argocd
```

All pods should be in `Running` state.

## Access ArgoCD UI

### Method 1: Port Forward (Recommended)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: https://localhost:8080

### Method 2: NodePort

```bash
# Expose ArgoCD server
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get the access URL
echo "https://$(minikube ip):$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[1].nodePort}')"
```

### Get Admin Credentials

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

Login with:
- **Username**: `admin`
- **Password**: (from command above)

## Deploy Applications

This project includes two ArgoCD applications:

### 1. API Service Application

```bash
kubectl apply -f kubernetes/argocd/api-application.yaml
```

**Application Configuration:**
- **Name**: `api`
- **Source**: GitHub repository
- **Path**: `kubernetes/api/`
- **Target Namespace**: `api`
- **Sync Policy**: Automated with self-heal
- **Auto-create Namespace**: Yes

### 2. Auxiliary Service Application

```bash
kubectl apply -f kubernetes/argocd/aux-application.yaml
```

**Application Configuration:**
- **Name**: `aux`
- **Source**: GitHub repository
- **Path**: `kubernetes/aux/`
- **Target Namespace**: `aux`
- **Sync Policy**: Automated with self-heal
- **Auto-create Namespace**: Yes

## Application Configuration

### ArgoCD Application Manifest Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <service-name>
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<repo>
    targetRevision: main
    path: kubernetes/<service>/
  destination:
    server: https://kubernetes.default.svc
    namespace: <service-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
```

### Key Sync Policy Options

- **`prune: true`** - Deletes resources not defined in Git
- **`selfHeal: true`** - Automatically syncs when cluster state differs from Git
- **`CreateNamespace: true`** - Creates target namespace if it doesn't exist

## Monitoring Deployments

### Check Application Status

```bash
# List applications
kubectl get applications -n argocd

# Get detailed status
kubectl describe application api -n argocd
kubectl describe application aux -n argocd
```

### Check Pod Status

```bash
# API service
kubectl get pods -n api
kubectl logs -n api -l app=api

# AUX service
kubectl get pods -n aux
kubectl logs -n aux -l app=aux
```

### View ArgoCD Events

```bash
# Watch sync status
kubectl get applications -n argocd -w

# Check sync events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

## Troubleshooting

### Applications Stuck in "OutOfSync"

**Symptoms:**
- Application shows `OutOfSync` in ArgoCD UI
- Manual sync fails

**Solutions:**

1. **Check repository access:**
   ```bash
   # Verify ArgoCD can reach Git repo
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
   ```

2. **Validate manifests:**
   ```bash
   # Test manifests locally
   kubectl apply --dry-run=client -f kubernetes/api/
   kubectl apply --dry-run=server -f kubernetes/api/
   ```

3. **Force sync:**
   ```bash
   # Delete and recreate application
   kubectl delete application api -n argocd
   kubectl apply -f kubernetes/argocd/api-application.yaml
   ```

### Pods in ImagePullBackOff

**Symptoms:**
- Pods stuck pulling container images from ECR
- Error: `no basic auth credentials`

**Solution:**

Create ECR pull secrets in target namespaces:

```bash
# Get ECR credentials
ECR_PASSWORD=$(aws ecr get-login-password --region eu-west-1)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create secret in API namespace
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --namespace=api

# Create secret in AUX namespace
kubectl create secret docker-registry ecr-registry-secret \
  --docker-server=${ACCOUNT_ID}.dkr.ecr.eu-west-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --namespace=aux
```

**Note:** ECR tokens expire after 12 hours. Consider using a cronjob to refresh them.

### AWS Credentials Not Found

**Symptoms:**
- Pods show `CreateContainerConfigError`
- Error: `Secret "api-aws-credentials" not found`

**Solution:**

Generate and apply AWS credential secrets:

```bash
# Generate secrets from Terraform outputs
bash scripts/setup-k8s-secrets.sh

# Apply secrets
kubectl apply -f infrastructure/kubernetes/api-aws-credentials-secret.yaml
kubectl apply -f infrastructure/kubernetes/aux-aws-credentials-secret.yaml

# Verify secrets exist
kubectl get secret api-aws-credentials -n api
kubectl get secret aux-aws-credentials -n aux
```

### Pods in CrashLoopBackOff

**Symptoms:**
- Pods restart repeatedly
- Application logs show errors

**Debugging:**

```bash
# Check pod logs
kubectl logs -n api <pod-name> --previous

# Check pod events
kubectl describe pod -n api <pod-name>

# Check resource limits
kubectl top pods -n api
```

**Common causes:**
- AWS access denied (check IAM role permissions)
- Application configuration errors
- Resource limits too low
- Health check failures

### ArgoCD Self-Heal Not Working

**Symptoms:**
- Manual kubectl changes persist
- ArgoCD doesn't revert manual changes

**Solution:**

Ensure sync policy includes `selfHeal: true`:

```bash
# Edit application
kubectl edit application api -n argocd

# Add under spec.syncPolicy.automated:
# selfHeal: true
```

## Corporate Proxy Setup

**Only needed if you encounter TLS certificate errors when pulling container images.**

### Problem

Corporate proxy intercepts HTTPS traffic causing:
```
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

### Solution: Configure Docker Desktop CA Certificate

#### 1. Extract Corporate CA Certificate

**From macOS Keychain:**
```bash
# Open Keychain Access, find corporate CA, export as corporate-ca.cer
open "/System/Applications/Utilities/Keychain Access.app"

# Convert to PEM format
openssl x509 -inform DER -in ~/Downloads/corporate-ca.cer -out ~/Downloads/corporate-ca.pem
```

**OR from TLS connection:**
```bash
openssl s_client -showcerts -connect ghcr.io:443 </dev/null 2>/dev/null | \
  openssl x509 -outform PEM > ~/Downloads/corporate-ca.pem
```

#### 2. Configure Docker Desktop

1. Open **Docker Desktop** → **Settings** → **Docker Engine**
2. Add to JSON config:
   ```json
   {
     "certs": {
       "ghcr.io": ["/Users/YOUR_USERNAME/Downloads/corporate-ca.pem"],
       "quay.io": ["/Users/YOUR_USERNAME/Downloads/corporate-ca.pem"]
     }
   }
   ```
3. Click **Apply & Restart**

#### 3. Test Configuration

```bash
docker pull ghcr.io/dexidp/dex:v2.43.0
```

### Manual Image Loading (Fallback)

If pods still fail to pull images:

```bash
# Pull image locally
docker pull ghcr.io/dexidp/dex:v2.43.0

# Load into Minikube
docker save ghcr.io/dexidp/dex:v2.43.0 | (eval $(minikube docker-env) && docker load)

# Patch deployment to use local images
kubectl patch deployment argocd-dex-server -n argocd --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "IfNotPresent"}]'
```

## Useful Commands

### Application Management

```bash
# List applications
kubectl get applications -n argocd

# Get application details
kubectl describe application api -n argocd

# Delete application (but keep resources)
kubectl delete application api -n argocd --cascade=false

# Force sync
kubectl patch application api -n argocd --type merge -p '{"operation": {"initiatedBy": {"automated": false}, "sync": {"revision": "HEAD"}}}'
```

### ArgoCD CLI

```bash
# Install ArgoCD CLI
brew install argocd

# Login
argocd login localhost:8080

# List applications
argocd app list

# Get application details
argocd app get api

# Sync application
argocd app sync api

# View logs
argocd app logs api
```

## Clean Up

### Remove Applications

```bash
# Delete ArgoCD applications (keeps resources)
kubectl delete application api aux -n argocd

# Delete namespaces and resources
kubectl delete namespace api aux
```

### Uninstall ArgoCD

```bash
# Delete ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Delete namespace
kubectl delete namespace argocd
```

### Stop Minikube

```bash
minikube stop
minikube delete  # Complete cleanup
```

## Best Practices

1. **Use Automated Sync** - Enable `automated`, `prune`, and `selfHeal` for production
2. **Pin Image Tags** - Use commit SHA tags instead of `latest`
3. **Namespace Isolation** - Deploy each service in its own namespace
4. **Secret Management** - Never commit secrets; use Kubernetes secrets or external secret managers
5. **Health Checks** - Define proper readiness and liveness probes
6. **Resource Limits** - Set CPU and memory limits for all containers
7. **RBAC** - Configure least-privilege access for ArgoCD service accounts

## Related Documentation

- [Application README](../../app/README.md) - Service details and local development
- [Infrastructure README](../../infrastructure/README.md) - AWS resources and Terraform
- [GitHub Actions Setup](../../infrastructure/GITHUB_OIDC_SETUP.md) - CI/CD pipeline configuration
