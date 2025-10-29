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
- API service role (S3 + SSM access)
- Auxiliary service role (SSM access only)
- GitHub Actions role (ECR push access via OIDC)
- Policies for role assumption and resource access

## IAM Role Assumption Pattern

The infrastructure implements AWS security best practices for Kubernetes workloads:

**Base IAM User** (`kantox-minikube-base-{env}`):
- Minimal permissions - can only assume service roles
- Credentials stored in Kubernetes secrets
- Injected into pods via environment variables

**Service Roles**:
- `kantox-api-role-{env}` - Full S3 and SSM permissions
- `kantox-aux-role-{env}` - SSM permissions only
- Can be assumed by the base IAM user

**Application Flow**:
1. Pod starts with base user credentials
2. Application reads `AWS_ROLE_ARN` environment variable
3. Uses STS AssumeRole to get temporary credentials
4. Uses temporary credentials for all AWS operations

This provides:
- Least privilege access (base user has minimal permissions)
- Temporary credentials (auto-rotating)
- Service isolation (different roles per service)
- Audit trail (STS assume role logged in CloudTrail)

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

### Generate Kubernetes Secrets

After Terraform deployment, generate the secrets needed for Kubernetes:

```bash
cd ..
bash scripts/setup-k8s-secrets.sh
```

This creates:
- `infrastructure/kubernetes/api-aws-credentials-secret.yaml`
- `infrastructure/kubernetes/aux-aws-credentials-secret.yaml`

These files contain the base IAM user credentials and role ARNs. Apply them to your cluster:

```bash
kubectl apply -f infrastructure/kubernetes/api-aws-credentials-secret.yaml
kubectl apply -f infrastructure/kubernetes/aux-aws-credentials-secret.yaml
```

**Important**: These secret files are gitignored and should never be committed.

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
- `service_role_arns` - IAM role ARNs for applications
- `ecr_repository_urls` - Docker image registry URLs
- `minikube_base_credentials` - Base IAM user credentials (sensitive)

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
