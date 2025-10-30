data "aws_caller_identity" "current" {}

# ============================================================================
# BASE IAM USER - For Minikube pods to assume service roles
# ============================================================================
# This user has minimal permissions - only to assume service-specific roles
# Credentials will be stored in Kubernetes secrets and injected into pods

resource "aws_iam_user" "minikube_base" {
  name = "${var.project_name}-minikube-base-${var.environment}"

  tags = merge(var.tags, {
    Purpose = "Base user for Minikube pods to assume service roles"
  })
}

resource "aws_iam_access_key" "minikube_base" {
  user = aws_iam_user.minikube_base.name
}

# Policy allowing base user to assume service roles
resource "aws_iam_policy" "assume_service_roles" {
  name        = "${var.project_name}-assume-service-roles-${var.environment}"
  description = "Allow assuming service-specific IAM roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-api-role-${var.environment}",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-aux-role-${var.environment}"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_user_policy_attachment" "minikube_base_assume" {
  user       = aws_iam_user.minikube_base.name
  policy_arn = aws_iam_policy.assume_service_roles.arn
}

# ============================================================================
# IAM ROLES - Service-specific roles with actual permissions
# ============================================================================

# IAM role for API service with S3 access
# For Minikube: Base IAM user can assume this role
# For EKS: Would add OIDC trust policy (commented out for future use)
resource "aws_iam_role" "api_namespace_role" {
  name = "${var.project_name}-api-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.minikube_base.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Service = "api"
  })
}

# S3 access policy for API service
resource "aws_iam_policy" "api_s3_access" {
  name        = "${var.project_name}-api-s3-access-${var.environment}"
  description = "Allow API service to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          [for k, v in module.s3_bucket : v.s3_bucket_arn],
          [for k, v in module.s3_bucket : "${v.s3_bucket_arn}/*"]
        )
      }
    ]
  })

  tags = var.tags
}

# SSM parameter access policy for API service
resource "aws_iam_policy" "api_ssm_access" {
  name        = "${var.project_name}-api-ssm-access-${var.environment}"
  description = "Allow API service to read SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [for k, v in module.ssm_parameter : v.ssm_parameter_arn]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "api_s3_attach" {
  role       = aws_iam_role.api_namespace_role.name
  policy_arn = aws_iam_policy.api_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "api_ssm_attach" {
  role       = aws_iam_role.api_namespace_role.name
  policy_arn = aws_iam_policy.api_ssm_access.arn
}

# IAM role for AUX service (has both S3 and SSM access)
# This is the internal service that handles all AWS operations
# For Minikube: Base IAM user can assume this role
# For EKS: Would add OIDC trust policy (commented out for future use)
resource "aws_iam_role" "aux_namespace_role" {
  name = "${var.project_name}-aux-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.minikube_base.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Service = "aux"
  })
}

# S3 access policy for AUX service
resource "aws_iam_policy" "aux_s3_access" {
  name        = "${var.project_name}-aux-s3-access-${var.environment}"
  description = "Allow AUX service to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          [for k, v in module.s3_bucket : v.s3_bucket_arn],
          [for k, v in module.s3_bucket : "${v.s3_bucket_arn}/*"]
        )
      }
    ]
  })

  tags = var.tags
}

# SSM parameter access policy for AUX service
resource "aws_iam_policy" "aux_ssm_access" {
  name        = "${var.project_name}-aux-ssm-access-${var.environment}"
  description = "Allow AUX service to read SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [for k, v in module.ssm_parameter : v.ssm_parameter_arn]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "aux_s3_attach" {
  role       = aws_iam_role.aux_namespace_role.name
  policy_arn = aws_iam_policy.aux_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "aux_ssm_attach" {
  role       = aws_iam_role.aux_namespace_role.name
  policy_arn = aws_iam_policy.aux_ssm_access.arn
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "minikube_base_credentials" {
  description = "Base credentials for Minikube (store in K8s secret)"
  value = {
    access_key_id     = aws_iam_access_key.minikube_base.id
    secret_access_key = aws_iam_access_key.minikube_base.secret
  }
  sensitive = true
}

output "service_role_arns" {
  description = "ARNs of service roles to assume from pods"
  value = {
    api_role_arn = aws_iam_role.api_namespace_role.arn
    aux_role_arn = aws_iam_role.aux_namespace_role.arn
  }
}
