variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "kantox"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "s3_buckets" {
  description = "Map of S3 buckets to create"
  type = map(object({
    name               = string
    versioning_enabled = bool
  }))
}

variable "ssm_parameters" {
  description = "Map of SSM parameters to create"
  type = map(object({
    name  = string
    type  = string
    value = string
  }))
  # Note: Individual parameter values are marked sensitive in the module outputs
  # Cannot mark this as sensitive because it's used in for_each
}

variable "oidc_provider" {
  description = "OIDC provider URL for K8s (without https://)"
  type        = string
  default     = "localhost"
}

variable "api_service_account_name" {
  description = "Service account name for API namespace"
  type        = string
  default     = "api-sa"
}

variable "aux_service_account_name" {
  description = "Service account name for AUX namespace"
  type        = string
  default     = "aux-sa"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "jualbacar" # Update with your GitHub username/org
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "Kantox_CE_challenge"
}
