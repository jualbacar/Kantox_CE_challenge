aws_region   = "eu-west-1"
environment  = "qa"
project_name = "kantox"

s3_buckets = {
  data = {
    name               = "kantox-data-qa"
    versioning_enabled = true
  }
  logs = {
    name               = "kantox-logs-qa"
    versioning_enabled = true
  }
  backups = {
    name               = "kantox-backups-qa"
    versioning_enabled = true
  }
}

ssm_parameters = {
  api_config = {
    name  = "/kantox/qa/api/config"
    type  = "String"
    value = "{\"timeout\": 45, \"max_retries\": 5}"
  }
  database_url = {
    name  = "/kantox/qa/database/url"
    type  = "SecureString"
    value = "postgresql://qa-db.internal:5432/kantox_qa"
  }
  feature_flags = {
    name  = "/kantox/qa/features/flags"
    type  = "String"
    value = "{\"new_ui\": true, \"beta_features\": true}"
  }
}

github_org  = "jualbacar"
github_repo = "Kantox_CE_challenge"

