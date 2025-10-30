# Kantox Infrastructure

Terraform configuration for AWS resources including S3 buckets, SSM parameters, ECR repositories, and IAM roles with proper role assumption pattern for Kubernetes workloads.

## What Gets Created

### AWS Resources

**S3 Buckets** (per environment):
- `kantox-data-{env}` - Application data storage
- `kantox-logs-{env}` - Application logs
- `kantox-backups-{env}` - Backup storage
- All buckets have versioning and encryption enabled

**SSM Parameters** (per environment):
- `/kantox/{env}/api/config` - API configuration
- `/kantox/{env}/database/url` - Database connection string (encrypted)
- `/kantox/{env}/features/flags` - Feature toggle configuration

**ECR Repositories**:
- `kantox-api` - API service Docker images
- `kantox-aux` - Auxiliary service Docker images
- Both with lifecycle policies to keep last 5 images

**IAM Resources**:
- Base IAM user for Minikube (minimal permissions - can only assume roles)
- AUX service role (S3 + SSM access) - **only service with AWS permissions**
- API service role (deprecated in v2.0.0 - API is now a gateway with no AWS access)
- GitHub Actions role (ECR push access via OIDC)
- Policies for role assumption and resource access

## IAM Role Assumption Pattern

The infrastructure implements AWS security best practices with a **BFF/API Gateway architecture**:

### Architecture Pattern (v2.0.0+)
- **API Service**: Public gateway with **no AWS credentials** - proxies requests via HTTP
- **AUX Service**: Internal backend with full AWS access - handles all AWS operations

### IAM Structure

**Base IAM User** (`kantox-minikube-base-{env}`):
- Minimal permissions - can only assume the AUX service role
- Credentials stored in Kubernetes secret (AUX namespace only)
- Injected into AUX pods via environment variables

**Service Roles**:
- `kantox-aux-role-{env}` - **Active** - Full S3 and SSM permissions
- `kantox-api-role-{env}` - **Deprecated** - No longer used (API is now a gateway)

### Application Flow (AUX Service Only):
1. AUX pod starts with base user credentials
2. Application reads `AWS_ROLE_ARN` environment variable
3. Uses STS AssumeRole to get temporary credentials
4. Uses temporary credentials for all AWS operations
5. API service connects to AUX via HTTP (no AWS credentials needed)

### Security Benefits:
- **Reduced Attack Surface**: Only internal service has AWS credentials
- **Least Privilege**: Base user can only assume one role
- **Temporary Credentials**: Auto-rotating via STS
- **Service Isolation**: Gateway and backend completely separated
- **Audit Trail**: STS assume role logged in CloudTrail
- **Zero Trust**: API service cannot access AWS even if compromised

## Quick Start

### Initial Setup

```bash
cd infrastructure

# Initialize Terraform
terraform init

# Create dev workspace
terraform workspace new dev

# Preview changes
terraform plan -var-file=eu-west-1/dev/dev.tfvars

# Deploy
terraform apply -var-file=eu-west-1/dev/dev.tfvars
```

### Generate Kubernetes Secret

After Terraform deployment, generate the secret needed for the AUX service:

```bash
cd ..
bash scripts/setup-k8s-secrets.sh
```

This creates:
- `kubernetes/aux-aws-credentials-secret.yaml`

This file contains the base IAM user credentials and AUX role ARN. Apply it to your cluster:

```bash
kubectl apply -f kubernetes/aux-aws-credentials-secret.yaml
```

**Important**: 
- This secret file is gitignored and should never be committed
- Only the AUX service needs AWS credentials (v2.0.0+ BFF architecture)
- API service has no AWS access - it's a pure gateway

## Working with Environments

Terraform workspaces provide environment isolation:

```bash
# List all workspaces
terraform workspace list

# Switch to an environment
terraform workspace select dev

# Create new environment
terraform workspace new qa
terraform apply -var-file=eu-west-1/qa/qa.tfvars

# View current workspace
terraform workspace show
```

Each workspace maintains its own state file in `terraform.tfstate.d/{workspace}/`.

## Adding Resources

To add new S3 buckets or SSM parameters, edit the appropriate tfvars file:

```hcl
# In eu-west-1/dev/dev.tfvars
s3_buckets = {
  data = { ... }
  logs = { ... }
  backups = { ... }
  new_bucket = {
    name               = "kantox-new-bucket-dev"
    versioning_enabled = true
  }
}

ssm_parameters = {
  api_config = { ... }
  database_url = { ... }
  feature_flags = { ... }
  new_param = {
    name  = "/kantox/dev/new/parameter"
    type  = "String"
    value = "some-value"
  }
}
```

Then apply:

```bash
terraform workspace select dev
terraform apply -var-file=eu-west-1/dev/dev.tfvars
```

## Viewing Outputs

After deployment, view important information:

```bash
terraform output

# View specific outputs
terraform output s3_bucket_names
terraform output service_role_arns

# View sensitive outputs (IAM credentials)
terraform output -json minikube_base_credentials
```

Key outputs:
- `s3_bucket_names` - Names of created S3 buckets
- `s3_bucket_arns` - ARNs for IAM policies
- `ssm_parameter_names` - Parameter Store paths
- `service_role_arns` - IAM role ARNs (only AUX role used in v2.0.0+)
- `ecr_repository_urls` - Docker image registry URLs
- `minikube_base_credentials` - Base IAM user credentials (sensitive, AUX service only)

## File Structure

```
infrastructure/
├── main.tf              # Provider and Terraform configuration
├── variables.tf         # Input variable declarations
├── s3.tf               # S3 buckets using registry module
├── ecr.tf              # ECR repositories for Docker images
├── parameter-store.tf   # SSM parameters using registry module
├── iam.tf              # IAM users, roles, and policies
├── github-oidc.tf      # GitHub Actions OIDC provider
├── outputs.tf          # Output values
└── eu-west-1/          # Region-specific configurations
    ├── dev/
    │   └── dev.tfvars
    ├── qa/
    │   └── qa.tfvars
    └── prod/
        └── prod.tfvars
```
