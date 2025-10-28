output "region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "s3_bucket_names" {
  description = "Map of S3 bucket names"
  value       = { for k, v in module.s3_bucket : k => v.s3_bucket_id }
}

output "s3_bucket_arns" {
  description = "Map of S3 bucket ARNs"
  value       = { for k, v in module.s3_bucket : k => v.s3_bucket_arn }
}

output "ssm_parameter_names" {
  description = "Map of SSM parameter names"
  value       = { for k, v in module.ssm_parameter : k => v.ssm_parameter_name }
}

output "ssm_parameter_arns" {
  description = "Map of SSM parameter ARNs"
  value       = { for k, v in module.ssm_parameter : k => v.ssm_parameter_arn }
}

output "iam_roles" {
  description = "IAM role ARNs for Kubernetes service accounts"
  value = {
    api_namespace_role = aws_iam_role.api_namespace_role.arn
    aux_namespace_role = aws_iam_role.aux_namespace_role.arn
  }
}
