module "s3_bucket" {
  source   = "terraform-aws-modules/s3-bucket/aws"
  version  = "~> 4.0"
  for_each = var.s3_buckets

  bucket = each.value.name

  versioning = {
    enabled = each.value.versioning_enabled
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = merge(var.tags, {
    Environment = var.environment
  })
}
