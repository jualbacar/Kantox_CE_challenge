# GitHub OIDC Setup for AWS

Guide for setting up GitHub Actions OIDC authentication with AWS to enable secure CI/CD without storing static AWS credentials.

## Overview

This configuration establishes OpenID Connect (OIDC) authentication between GitHub Actions and AWS, allowing your CI/CD pipeline to:
- Build and push Docker images to ECR
- Access AWS resources securely without static credentials
- Use temporary, scoped credentials that expire automatically

## Architecture

```
┌─────────────────┐
│ GitHub Actions  │
│                 │
│ 1. Request token│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GitHub OIDC     │
│ token.actions   │
│ .githubusercontent│
│ .com            │
└────────┬────────┘
         │
         │ 2. JWT Token
         ▼
┌─────────────────┐
│ AWS STS         │
│                 │
│ 3. Assume Role  │
└────────┬────────┘
         │
         │ 4. Temporary credentials
         ▼
┌─────────────────┐
│ GitHub Actions  │
│                 │
│ 5. Use AWS CLI  │
└─────────────────┘
```

## Prerequisites

- AWS account with admin access
- GitHub repository
- Terraform >= 1.5.0 installed
- AWS CLI configured

## Setup Steps

### 1. Deploy OIDC Infrastructure with Terraform

The Terraform configuration in `infrastructure/github-oidc.tf` creates:
- GitHub OIDC identity provider in AWS
- IAM role for GitHub Actions to assume
- IAM policies for ECR access
- ECR repositories for API and AUX services

```bash
cd infrastructure

# Initialize Terraform
terraform init

# Select workspace (dev/qa/prod)
terraform workspace select dev

# Plan changes
terraform plan -var-file=eu-west-1/dev/dev.tfvars

# Apply configuration
terraform apply -var-file=eu-west-1/dev/dev.tfvars
```

**Created Resources:**
- OIDC Provider: `token.actions.githubusercontent.com`
- IAM Role: `kantox-github-actions-<environment>`
- ECR Repositories: `kantox-api`, `kantox-aux`

### 2. Get the IAM Role ARN

After Terraform apply completes:

```bash
terraform output github_actions_role_arn
```

Example output:
```
arn:aws:iam::035895024082:role/kantox-github-actions-dev
```

### 3. Configure GitHub Repository Secret

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add:
   - **Name**: `AWS_GITHUB_ACTIONS_ROLE_ARN`
   - **Value**: (paste the role ARN from step 2)

### 4. Configure GitHub Workflow

The workflow uses the `aws-actions/configure-aws-credentials` action:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for OIDC
      contents: read
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE_ARN }}
          aws-region: eu-west-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: sha-${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/kantox-api:$IMAGE_TAG ./app
          docker push $ECR_REGISTRY/kantox-api:$IMAGE_TAG
```

**Key points:**
- `permissions.id-token: write` - Required for OIDC token generation
- `role-to-assume` - The IAM role ARN from GitHub secret
- No AWS access keys needed!

### 5. Test the Setup

#### Push a Commit

```bash
git add .
git commit -m "Test OIDC authentication"
git push origin main
```

#### Check GitHub Actions

1. Go to **Actions** tab in your repository
2. Watch the workflow run
3. Verify "Configure AWS credentials" step succeeds
4. Confirm ECR push completes

## Security Features

### 1. Repository-Scoped Trust Policy

The IAM role trust policy restricts access to your specific repository:

```hcl
# infrastructure/github-oidc.tf
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}
```

**This means:**
- Only your repository can assume the role
- Other repositories cannot access your AWS account
- Forks cannot assume the role

### 2. Least Privilege Permissions

The role has minimal permissions:

```hcl
# ECR permissions only for kantox-* repositories
resource "aws_iam_policy" "github_actions_ecr" {
  name        = "kantox-github-actions-ecr-${var.environment}"
  description = "Allows GitHub Actions to push to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/kantox-*"
        ]
      }
    ]
  })
}
```

### 3. Temporary Credentials

- Credentials are valid only for the duration of the workflow run (typically < 1 hour)
- Cannot be reused outside GitHub Actions
- Automatically expire after use

### 4. No Static Secrets

- ✅ No AWS access keys stored in GitHub
- ✅ No long-term credentials
- ✅ Credentials cannot leak via logs or cache
- ✅ Automatic rotation (new credentials each run)

## Terraform Configuration

### Key Variables

Defined in `infrastructure/variables.tf`:

```hcl
variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "jualbacar"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "Kantox_CE_challenge"
}
```

### Environment-Specific Values

In `infrastructure/eu-west-1/dev/dev.tfvars`:

```hcl
environment = "dev"
aws_region  = "eu-west-1"
```

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause:** Trust policy doesn't match your repository.

**Solution:**

1. Verify variables in Terraform:
   ```bash
   terraform console
   > var.github_org
   > var.github_repo
   ```

2. Check the expected subject claim:
   ```
   repo:<github_org>/<github_repo>:*
   ```

3. Update variables and reapply:
   ```bash
   terraform apply -var-file=eu-west-1/dev/dev.tfvars
   ```

### Error: "No OIDC provider found"

**Cause:** OIDC provider doesn't exist in AWS.

**Solution:**

1. Check AWS Console → IAM → Identity providers
2. Verify provider exists: `token.actions.githubusercontent.com`
3. If missing, apply Terraform:
   ```bash
   terraform apply -var-file=eu-west-1/dev/dev.tfvars
   ```

### Error: "Missing required permissions id-token: write"

**Cause:** Workflow doesn't have OIDC token permissions.

**Solution:**

Add to your workflow:
```yaml
permissions:
  id-token: write
  contents: read
```

### Error: "Access Denied" when pushing to ECR

**Cause:** IAM role lacks ECR permissions.

**Solution:**

1. Verify policy attachment:
   ```bash
   aws iam list-attached-role-policies \
     --role-name kantox-github-actions-dev
   ```

2. Check ECR repository names match:
   ```bash
   aws ecr describe-repositories --region eu-west-1
   ```

3. Ensure repository names start with `kantox-*`

### Error: "Token expired"

**Cause:** Workflow took longer than token lifetime.

**Solution:**

This is rare, but if it happens:
1. Break workflow into smaller jobs
2. Re-authenticate in long-running jobs:
   ```yaml
   - name: Re-authenticate with AWS
     uses: aws-actions/configure-aws-credentials@v4
     with:
       role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE_ARN }}
       aws-region: eu-west-1
   ```

## Verification Commands

### Check OIDC Provider

```bash
aws iam list-open-id-connect-providers
```

Expected output:
```json
{
  "OpenIDConnectProviderList": [
    {
      "Arn": "arn:aws:iam::035895024082:oidc-provider/token.actions.githubusercontent.com"
    }
  ]
}
```

### Check IAM Role

```bash
aws iam get-role --role-name kantox-github-actions-dev
```

### Check Trust Policy

```bash
aws iam get-role --role-name kantox-github-actions-dev \
  --query 'Role.AssumeRolePolicyDocument' --output json
```

### List Attached Policies

```bash
aws iam list-attached-role-policies --role-name kantox-github-actions-dev
```

### Test ECR Access (from workflow)

Add to workflow for debugging:
```yaml
- name: Test ECR access
  run: |
    aws ecr describe-repositories --region eu-west-1
    aws sts get-caller-identity
```

## Best Practices

1. **Use Specific Repository Matching**
   - Use exact repo names in trust policy, not wildcards
   - Example: `repo:org/repo:ref:refs/heads/main` for main branch only

2. **Limit Permissions**
   - Only grant what the workflow needs
   - Use resource-level restrictions (e.g., specific ECR repos)

3. **Monitor Usage**
   - Enable CloudTrail logging for AssumeRole calls
   - Set up alerts for unexpected role usage

4. **Rotate Regularly**
   - Review and update trust policies quarterly
   - Remove unused repositories from trust policy

5. **Use Environment Secrets**
   - Use GitHub environment secrets for production
   - Require manual approval for sensitive deployments

## Additional Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Provider Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform OIDC Provider Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider)

## Related Documentation

- [Infrastructure README](README.md) - Terraform setup and AWS resources
- [ArgoCD Setup](../kubernetes/argocd/README.md) - GitOps deployment
- [Application README](../app/README.md) - Service details
