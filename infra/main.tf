data "aws_caller_identity" "current" {}

locals {
  name_prefix = lower(replace("${var.project_name}-${var.environment}", "_", "-"))
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
      CostCenter  = var.cost_center
    }
  )
}

# s3_artifacts is out of scope for Sesión 03 (S3 datalake, RDS, DynamoDB,
# Athena) — it packages code for Glue/Lambda jobs, which this session does
# not cover, and no other module depends on it. Re-enable if a later
# session introduces Glue/Lambda jobs: write a script that packages src/
# into artifacts/data_platform_bundle.zip (see var.artifact_path), then
# uncomment this block and the matching outputs in outputs.tf.
# module "s3_artifacts" {
#   source = "./modules/s3-artifacts"
#
#   name_prefix                       = local.name_prefix
#   account_id                        = data.aws_caller_identity.current.account_id
#   artifact_path                     = var.artifact_path
#   artifact_bucket_suffix            = var.artifact_bucket_suffix
#   artifact_bucket_force_destroy     = var.artifact_bucket_force_destroy
#   enable_artifact_bucket_versioning = var.enable_artifact_bucket_versioning
#   execution_role_name               = var.execution_role_name
#   log_retention_days                = var.log_retention_days
#   common_tags                       = local.common_tags
# }

module "s3_datalake" {
  source = "./modules/s3-datalake"

  name_prefix               = local.name_prefix
  account_id                = data.aws_caller_identity.current.account_id
  bucket_suffix             = var.datalake_bucket_suffix
  enable_versioning         = var.enable_datalake_versioning
  lifecycle_transition_days = var.datalake_lifecycle_transition_days
  force_destroy             = var.datalake_bucket_force_destroy
  common_tags               = local.common_tags
}

module "rds" {
  source = "./modules/rds"

  name_prefix        = local.name_prefix
  db_name            = var.rds_db_name
  db_username        = var.rds_db_username
  db_password        = var.rds_db_password
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  student_ip_cidr    = var.student_ip_cidr
  log_retention_days = var.log_retention_days
  common_tags        = local.common_tags
}

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name  = var.dynamodb_table_name
  common_tags = local.common_tags
}

module "athena" {
  source = "./modules/athena"

  name_prefix          = local.name_prefix
  datalake_bucket_name = module.s3_datalake.bucket_name
  datalake_bucket_arn  = module.s3_datalake.bucket_arn
  data_prefix          = module.s3_datalake.raw_prefix
  common_tags          = local.common_tags
}

resource "aws_sns_topic" "budget_alerts" {
  count = var.enable_budget_guardrail && var.budget_alert_email != "" ? 1 : 0
  name  = "${local.name_prefix}-budget-alerts"
  tags  = local.common_tags
}

resource "aws_sns_topic_subscription" "budget_email" {
  count     = var.enable_budget_guardrail && var.budget_alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "email"
  endpoint  = var.budget_alert_email
}

resource "aws_budgets_budget" "monthly" {
  count             = var.enable_budget_guardrail ? 1 : 0
  name              = "${local.name_prefix}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = tostring(var.budget_limit_usd)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  }
}
