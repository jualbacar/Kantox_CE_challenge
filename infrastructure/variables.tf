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
  # Cannot mark as sensitive: used in for_each expressions
}

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
