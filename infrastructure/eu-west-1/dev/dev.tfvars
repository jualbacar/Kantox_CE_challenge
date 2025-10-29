aws_region   = "eu-west-1"
environment  = "dev"
project_name = "kantox"

s3_buckets = {
  data = {
    name               = "kantox-data-dev"
    versioning_enabled = true
  }
  logs = {
    name               = "kantox-logs-dev"
    versioning_enabled = true
  }
  backups = {
    name               = "kantox-backups-dev"
    versioning_enabled = true
  }
}

ssm_parameters = {
  api_config = {
    name  = "/kantox/dev/api/config"
    type  = "String"
    value = "{\"timeout\": 30, \"max_retries\": 3}"
  }
  database_url = {
    name  = "/kantox/dev/database/url"
    type  = "SecureString"
    value = "postgresql://localhost:5432/kantox_dev"
  }
  feature_flags = {
    name  = "/kantox/dev/features/flags"
    type  = "String"
    value = "{\"new_ui\": true, \"beta_features\": true}"
  }
}

github_org  = "jualbacar"
github_repo = "Kantox_CE_challenge"

