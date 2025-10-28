# Amazon ECR Repositories for Docker images

# ECR Repository for API service
resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "api"
    Project     = var.project_name
  }
}

# ECR Repository for Auxiliary service
resource "aws_ecr_repository" "aux" {
  name                 = "${var.project_name}-aux"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-aux"
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "aux"
    Project     = var.project_name
  }
}

# Lifecycle policy to keep only the last N images
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "aux" {
  repository = aws_ecr_repository.aux.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Outputs
output "ecr_repository_api_url" {
  description = "URL of the API ECR repository"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_aux_url" {
  description = "URL of the AUX ECR repository"
  value       = aws_ecr_repository.aux.repository_url
}

output "ecr_repository_api_arn" {
  description = "ARN of the API ECR repository"
  value       = aws_ecr_repository.api.arn
}

output "ecr_repository_aux_arn" {
  description = "ARN of the AUX ECR repository"
  value       = aws_ecr_repository.aux.arn
}
