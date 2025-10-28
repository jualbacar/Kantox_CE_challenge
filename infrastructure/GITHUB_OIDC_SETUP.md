# GitHub OIDC Setup for AWS

This directory contains the Terraform configuration to set up GitHub Actions OIDC authentication with AWS.

## What This Does

1. **Creates GitHub OIDC Provider** in AWS
2. **Creates IAM Role** that GitHub Actions can assume
3. **Grants Permissions** for:
   - Pushing Docker images to ECR
4. **Creates ECR Repositories** for API and AUX services

**Note**: This setup is for minikube deployment. No EKS permissions are included.

## Setup Steps

### 1. Apply Terraform Configuration

```bash
cd infrastructure

# Initialize Terraform (if not already done)
terraform init

# Plan the changes
terraform plan

# Apply the configuration
terraform apply
```

This will create:
- GitHub OIDC identity provider
- IAM role: `kantox-github-actions-<environment>`
- IAM policies for ECR and EKS access
- ECR repositories: `kantox-api` and `kantox-aux`

### 2. Get the Role ARN

After applying, Terraform will output the GitHub Actions role ARN:

```bash
terraform output github_actions_role_arn
```

Copy this ARN - you'll need it for GitHub secrets.

### 3. Configure GitHub Repository Secret

1. Go to your GitHub repository: https://github.com/jualbacar/Kantox_CE_challenge
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add:
   - Name: `AWS_GITHUB_ACTIONS_ROLE_ARN`
   - Value: (paste the role ARN from step 2)

### 4. Test the Setup

#### Option A: Manual Test
1. Go to **Actions** tab in GitHub
2. Select "Test AWS OIDC Authentication" workflow
3. Click "Run workflow"
4. Check the logs to verify authentication works

#### Option B: Branch Test
```bash
git checkout -b test-oidc
git push origin test-oidc
```

This will trigger the test workflow automatically.

## How OIDC Works

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

**Benefits:**
- ✅ No static AWS credentials in GitHub
- ✅ Temporary credentials (expire automatically)
- ✅ Scoped to specific repository
- ✅ Follows AWS security best practices
- ✅ Simplified for demo/challenge environment

## Security Features

### 1. Repository Restriction
The IAM role trust policy only allows your specific repository:
```
repo:jualbacar/Kantox_CE_challenge:*
```

### 2. Limited Permissions
The role only has permissions for:
- ECR: Push/pull images for `kantox-*` repositories

### 3. No Long-term Credentials
- No AWS access keys stored in GitHub
- Credentials expire after the workflow run
- Can't be reused outside of GitHub Actions

## Files Created

```
infrastructure/
├── github-oidc.tf          # OIDC provider and IAM role
├── ecr.tf                  # ECR repositories
└── variables.tf            # Updated with GitHub variables

.github/
└── workflows/
    └── test-oidc.yml       # Test workflow
```

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause**: The trust policy doesn't match your repository.

**Fix**: Update `var.github_org` and `var.github_repo` in Terraform variables:
```terraform
github_org  = "your-username"
github_repo = "your-repo-name"
```

Then run `terraform apply` again.

### Error: "No OIDC provider found"

**Cause**: The OIDC provider wasn't created in AWS.

**Fix**: 
1. Check AWS Console → IAM → Identity providers
2. Verify the provider exists with URL: `token.actions.githubusercontent.com`
3. If missing, run `terraform apply`

### Error: "Access Denied" when accessing ECR

**Cause**: The IAM role doesn't have ECR permissions.

**Fix**: Verify the policy attachment:
```bash
aws iam list-attached-role-policies \
  --role-name kantox-github-actions-dev
```

## Next Steps

Once OIDC is working:
1. ✅ Build Docker images in GitHub Actions
2. ✅ Push images to ECR
3. ✅ Deploy to minikube locally or in CI
4. ✅ Update ConfigMaps with version info

See the main CI/CD pipeline in `.github/workflows/ci-cd.yml` (to be created next).

## References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
