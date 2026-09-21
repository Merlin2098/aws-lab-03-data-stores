# --- s3-artifacts ---
# Module disabled (see main.tf) — out of scope for Sesión 03. Uncomment
# these alongside the module block if re-enabled.

# output "artifact_bucket_name" {
#   description = "S3 bucket used for packaged runtime artifacts."
#   value       = module.s3_artifacts.artifact_bucket_name
# }
#
# output "artifact_bucket_arn" {
#   description = "ARN of the artifact bucket, for IAM policy scoping by other stacks."
#   value       = module.s3_artifacts.artifact_bucket_arn
# }
#
# output "artifact_bundle_s3_uri" {
#   description = "S3 URI of the packaged runtime artifact."
#   value       = module.s3_artifacts.artifact_bundle_s3_uri
# }
#
# output "data_job_execution_role_arn" {
#   description = "IAM role ARN for Glue or other batch data jobs."
#   value       = module.s3_artifacts.data_job_execution_role_arn
# }
#
# output "artifacts_log_group_name" {
#   description = "CloudWatch log group name for data jobs."
#   value       = module.s3_artifacts.log_group_name
# }
#
# output "artifacts_log_group_arn" {
#   description = "CloudWatch log group ARN for data jobs."
#   value       = module.s3_artifacts.log_group_arn
# }

# --- s3-datalake ---

output "datalake_bucket_name" {
  description = "Name of the data lake bucket."
  value       = module.s3_datalake.bucket_name
}

output "datalake_bucket_arn" {
  description = "ARN of the data lake bucket."
  value       = module.s3_datalake.bucket_arn
}

output "datalake_raw_prefix" {
  description = "Key prefix for raw event data."
  value       = module.s3_datalake.raw_prefix
}

output "datalake_curated_prefix" {
  description = "Key prefix for curated (Parquet, partitioned) event data."
  value       = module.s3_datalake.curated_prefix
}

# --- rds ---

output "rds_endpoint" {
  description = "Connection endpoint (host:port) for the RDS instance."
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Port the RDS instance listens on."
  value       = module.rds.port
}

output "rds_db_name" {
  description = "Name of the initial database."
  value       = module.rds.db_name
}

output "rds_security_group_id" {
  description = "Security group ID restricting access to the student IP."
  value       = module.rds.security_group_id
}

output "rds_log_group_name" {
  description = "CloudWatch log group name for RDS PostgreSQL logs."
  value       = module.rds.log_group_name
}

output "rds_log_group_arn" {
  description = "CloudWatch log group ARN for RDS PostgreSQL logs."
  value       = module.rds.log_group_arn
}

# --- dynamodb ---

output "dynamodb_table_name" {
  description = "Name of the DynamoDB tracking table."
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB tracking table."
  value       = module.dynamodb.table_arn
}

# --- athena ---

output "athena_database_name" {
  description = "Glue Catalog database name for the lab dataset."
  value       = module.athena.database_name
}

output "athena_table_name" {
  description = "Glue Catalog table name for tracking events."
  value       = module.athena.table_name
}

output "athena_workgroup_name" {
  description = "Athena workgroup name to run queries against."
  value       = module.athena.workgroup_name
}

# --- budget guardrail ---

output "budget_name" {
  description = "AWS Budget name for monthly cost governance. Empty string when enable_budget_guardrail is false."
  value       = var.enable_budget_guardrail ? aws_budgets_budget.monthly[0].name : ""
}

output "budget_alert_sns_arn" {
  description = "SNS topic ARN for budget alerts. Empty string when the guardrail is disabled or no alert email is configured."
  value       = var.enable_budget_guardrail && var.budget_alert_email != "" ? aws_sns_topic.budget_alerts[0].arn : ""
}
