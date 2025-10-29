# CI/CD Pipeline Documentation

Automated build and deployment pipeline using GitHub Actions, AWS ECR, and ArgoCD GitOps.

## Overview

The CI/CD pipeline automatically builds Docker images, pushes them to AWS ECR, updates Kubernetes manifests, and triggers ArgoCD deployments whenever code changes are pushed to the repository.

## Pipeline Flow

- Runs on pull requests targeting `main`
- Builds images but doesn't push to ECR or update manifests

```
┌─────────────────┐
│  Git Push to    │
│  main/develop   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GitHub Actions  │
│   Triggered     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Authenticate    │
│ with AWS OIDC   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Build Docker    │
│ Images (API+AUX)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Push to ECR     │
│ with SHA tags   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update K8s      │
│ Manifests       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Commit & Push   │
│ Manifest Changes│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ ArgoCD Detects  │
│ & Auto-Syncs    │
└─────────────────┘
```

## Image Tagging Strategy

### SHA Tags (Primary)
```
sha-09015f4
```
- Based on git commit SHA (7 characters)
- Immutable - specific version forever
- Used in Kubernetes deployments
- Enables easy rollback to any commit

### Branch Tags (Secondary)
```
latest-main
latest-develop
```
- Always points to latest build from branch
- Useful for quick testing
- Not used in production deployments

## Secrets Required

Configure these in **GitHub Repository Settings → Secrets and variables → Actions**:

### `AWS_GITHUB_ACTIONS_ROLE_ARN`
- **Description**: IAM role ARN for GitHub Actions to assume
- **Format**: `arn:aws:iam::ACCOUNT_ID:role/kantox-github-actions-ENV`
- **Setup**: Created by Terraform in `infrastructure/github-oidc.tf`
- **Permissions**: ECR push access

**To get the value**:
```bash
cd infrastructure
terraform output github_actions_role_arn
```

### Rollback Strategy

To rollback to a previous version:

1. Find previous commit SHA (e.g., `791611c`)
2. Update deployment manifests manually:
   ```bash
   # Edit kubernetes/api/deployment.yaml
   image: 035895024082.dkr.ecr.eu-west-1.amazonaws.com/kantox-api:sha-791611c
   ```
3. Commit and push
4. ArgoCD will sync the rollback

Or use ArgoCD rollback:
```bash
kubectl rollout undo deployment/api -n api
```
