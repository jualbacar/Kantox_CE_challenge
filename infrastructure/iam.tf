data "aws_caller_identity" "current" {}

# IAM role for API namespace service accounts with S3 access
resource "aws_iam_role" "api_namespace_role" {
  name = "${var.project_name}-api-namespace-role-${var.aws_region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:api:${var.api_service_account_name}"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# S3 access policy for API namespace
resource "aws_iam_policy" "api_s3_access" {
  name        = "${var.project_name}-api-s3-access-${var.aws_region}"
  description = "Allow API namespace pods to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# SSM parameter access policy for API namespace
resource "aws_iam_policy" "api_ssm_access" {
  name        = "${var.project_name}-api-ssm-access-${var.aws_region}"
  description = "Allow API namespace pods to read SSM parameters"

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

# IAM role for AUX namespace service accounts (no S3 access)
resource "aws_iam_role" "aux_namespace_role" {
  name = "${var.project_name}-aux-namespace-role-${var.aws_region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:aux:${var.aux_service_account_name}"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# SSM parameter access policy for AUX namespace
resource "aws_iam_policy" "aux_ssm_access" {
  name        = "${var.project_name}-aux-ssm-access-${var.aws_region}"
  description = "Allow AUX namespace pods to read SSM parameters"

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

resource "aws_iam_role_policy_attachment" "aux_ssm_attach" {
  role       = aws_iam_role.aux_namespace_role.name
  policy_arn = aws_iam_policy.aux_ssm_access.arn
}

