module "ssm_parameter" {
  source   = "terraform-aws-modules/ssm-parameter/aws"
  version  = "~> 1.0"
  for_each = var.ssm_parameters

  name  = each.value.name
  value = each.value.value
  type  = each.value.type

  tags = merge(var.tags, {
    Environment = var.environment
  })
}
