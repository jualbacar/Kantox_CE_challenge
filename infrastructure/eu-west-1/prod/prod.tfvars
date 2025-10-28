aws_region  = "eu-west-1"
environment = "prod"

s3_buckets = {
  data = {
    name               = "kantox-data-prod"
    versioning_enabled = true
  }
  logs = {
    name               = "kantox-logs-prod"
    versioning_enabled = true
  }
  backups = {
    name               = "kantox-backups-prod"
    versioning_enabled = true
  }
}

ssm_parameters = {
  api_config = {
    name  = "/kantox/prod/api/config"
    type  = "String"
    value = "{\"timeout\": 60, \"max_retries\": 5}"
  }
  database_url = {
    name  = "/kantox/prod/database/url"
    type  = "SecureString"
    value = "postgresql://prod-db.internal:5432/kantox_prod"
  }
  feature_flags = {
    name  = "/kantox/prod/features/flags"
    type  = "String"
    value = "{\"new_ui\": true, \"beta_features\": false}"
  }
}

oidc_provider = "localhost"
