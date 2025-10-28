# Kantox Infrastructure

This Terraform configuration manages AWS resources for the Kantox challenge including S3 buckets, SSM parameters, and IAM roles for Kubernetes service accounts.

## Structure

```
infrastructure/
├── main.tf              # Provider and Terraform configuration
├── variables.tf         # Input variable declarations
├── s3.tf               # S3 bucket creation using registry module
├── parameter-store.tf   # SSM parameters using registry module
├── iam.tf              # IAM roles for K8s service accounts
├── outputs.tf          # Output values
└── eu-west-1/          # Region-specific configurations
    ├── dev/
    │   └── dev.tfvars      # Development environment values
    ├── qa/
    │   └── qa.tfvars       # QA environment values
    └── prod/
        └── prod.tfvars     # Production environment values
```

## Architecture

This infrastructure uses:
- **Terraform Registry Modules**: `terraform-aws-modules/s3-bucket/aws` and `terraform-aws-modules/ssm-parameter/aws`
- **for_each Loops**: Dynamic resource creation from data structures
- **Terraform Workspaces**: Environment isolation using workspace feature

## Resources Created

Resources are defined per environment using tfvars files with `for_each` loops for dynamic creation.

### S3 Buckets
Environment-specific buckets (e.g., `kantox-data-dev-eu-west-1`, `kantox-logs-prod-eu-west-1`)
- Data bucket - Application data storage
- Logs bucket - Log storage
- Backups bucket - Backup storage

All buckets have versioning and encryption enabled.

### SSM Parameters
Environment-specific parameters (e.g., `/kantox/dev/api/config`, `/kantox/prod/database/url`)
- API configuration - API settings
- Database URL - Database connection (SecureString)
- Feature flags - Feature toggle configuration

### IAM Roles
- **API Namespace Role** - Access to S3 buckets and SSM parameters
- **AUX Namespace Role** - Access to SSM parameters only

## Usage

### Prerequisites
- Terraform >= 1.5.0
- AWS credentials configured
- Minikube or local Kubernetes cluster

### Initialize and Deploy

This infrastructure uses **Terraform workspaces** for environment management. All Terraform files (`.tf`) are shared in the root directory, and each environment has its own tfvars file.

#### Initial Setup

```bash
cd infrastructure

# Initialize Terraform (only needed once)
terraform init
```

#### Working with Environments

```bash
# Create and switch to dev workspace
terraform workspace new dev
terraform plan -var-file=eu-west-1/dev/dev.tfvars
terraform apply -var-file=eu-west-1/dev/dev.tfvars

# Create and switch to qa workspace
terraform workspace new qa
terraform plan -var-file=eu-west-1/qa/qa.tfvars
terraform apply -var-file=eu-west-1/qa/qa.tfvars

# Create and switch to prod workspace
terraform workspace new prod
terraform plan -var-file=eu-west-1/prod/prod.tfvars
terraform apply -var-file=eu-west-1/prod/prod.tfvars
```

#### Workspace Management

```bash
# List all workspaces
terraform workspace list

# Show current workspace
terraform workspace show

# Switch to existing workspace
terraform workspace select dev
terraform workspace select qa
terraform workspace select prod

# Apply changes to current workspace
terraform plan -var-file=eu-west-1/$(terraform workspace show)/$(terraform workspace show).tfvars
terraform apply -var-file=eu-west-1/$(terraform workspace show)/$(terraform workspace show).tfvars
```

#### State File Organization

Terraform automatically manages state files per workspace:
- Default workspace: `terraform.tfstate`
- Named workspaces: `terraform.tfstate.d/dev/terraform.tfstate`, `terraform.tfstate.d/qa/terraform.tfstate`, etc.

This approach provides clean environment isolation without needing separate backend configurations or directories.

### Adding New Resources

Edit the appropriate tfvars file for your environment:

```hcl
# In eu-west-1/dev/dev.tfvars
s3_buckets = {
  data = { ... }
  logs = { ... }
  backups = { ... }
  new_bucket = {
    name               = "kantox-new-bucket-dev-eu-west-1"
    versioning_enabled = true
  }
}
```

Then apply changes to that workspace:

```bash
terraform workspace select dev
terraform plan -var-file=eu-west-1/dev/dev.tfvars
terraform apply -var-file=eu-west-1/dev/dev.tfvars
```

### Multi-Region Support

To deploy to a different region, create a new region directory structure:

```bash
cd infrastructure
mkdir -p us-east-1/{dev,qa,prod}

# Copy and edit config files from eu-west-1
cp eu-west-1/dev/dev.tfvars us-east-1/dev/
cp eu-west-1/qa/qa.tfvars us-east-1/qa/
cp eu-west-1/prod/prod.tfvars us-east-1/prod/

# Edit the tfvars files in us-east-1/
# Update aws_region and resource names to reflect the new region
```

You can use the same workspace names but different var-files:

```bash
terraform workspace select dev
terraform apply -var-file=us-east-1/dev/dev.tfvars
```

### Kubernetes Integration

For local Minikube setup, the OIDC provider defaults to `localhost`. The IAM roles are configured to work with service accounts:

- Namespace: `api`, Service Account: `api-sa` → Full S3 and SSM access
- Namespace: `aux`, Service Account: `aux-sa` → SSM access only

To use these roles in your pods, annotate the service accounts:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-sa
  namespace: api
  annotations:
    eks.amazonaws.com/role-arn: <api_role_arn_from_output>
```

## Outputs

After deployment, view outputs:

```bash
terraform output
```

This displays S3 bucket names, SSM parameter paths, and IAM role ARNs.
