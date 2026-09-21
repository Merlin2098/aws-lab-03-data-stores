variable "project_name" {
  description = "Project name used in AWS resource naming."
  type        = string
  default     = "data-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag applied to all managed resources."
  type        = string
  default     = "data-engineering"
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "cost_center" {
  description = "Cost center tag for budget allocation and cost reporting."
  type        = string
  default     = "engineering"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days. Use 7 for demos and labs; set higher for production per compliance requirements."
  type        = number
  default     = 7
}

variable "enable_budget_guardrail" {
  description = "Whether to create the monthly AWS Budget (and its SNS alert topic, if an email is set). Off by default for student/demo use; enable for real deployments."
  type        = bool
  default     = false
}

variable "budget_limit_usd" {
  description = "Monthly AWS budget limit in USD. Alerts fire at 80% (actual) and 100% (forecasted). Only used when enable_budget_guardrail is true."
  type        = number
  default     = 25
}

variable "budget_alert_email" {
  description = "Email address for budget alerts. Leave empty to skip SNS subscription creation. Only used when enable_budget_guardrail is true."
  type        = string
  default     = ""
}

# --- s3-artifacts ---

variable "artifact_path" {
  description = "Path to the packaged runtime artifact produced by make package."
  type        = string
  default     = "../artifacts/data_platform_bundle.zip"
}

variable "artifact_bucket_suffix" {
  description = "Suffix appended to the generated artifact bucket name."
  type        = string
  default     = "artifacts"
}

variable "artifact_bucket_force_destroy" {
  description = "Whether Terraform may destroy the artifact bucket even when it contains objects. Keep true for dev and sandbox environments."
  type        = bool
  default     = true
}

variable "enable_artifact_bucket_versioning" {
  description = "Whether to enable versioning on the artifact bucket. Defaults to false to keep dev environments cheap and easy to destroy."
  type        = bool
  default     = false
}

variable "execution_role_name" {
  description = "IAM role name for AWS data jobs."
  type        = string
  default     = "data-job-execution-role"
}

# --- s3-datalake ---

variable "datalake_bucket_suffix" {
  description = "Suffix appended to the generated data lake bucket name."
  type        = string
  default     = "datalake"
}

variable "enable_datalake_versioning" {
  description = "Whether to enable versioning on the data lake bucket."
  type        = bool
  default     = true
}

variable "datalake_bucket_force_destroy" {
  description = "Whether Terraform may destroy the data lake bucket even when it contains objects. Keep true for dev and sandbox environments."
  type        = bool
  default     = true
}

variable "datalake_lifecycle_transition_days" {
  description = "Days after which objects under raw/ transition to STANDARD_IA."
  type        = number
  default     = 30
}

# --- rds ---

variable "rds_db_name" {
  description = "Name of the initial Postgres database."
  type        = string
  default     = "logistics"
}

variable "rds_db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "lab_admin"
}

variable "rds_db_password" {
  description = "Master password for the RDS instance. Supply via terraform.tfvars (gitignored) or TF_VAR_rds_db_password — never hardcode."
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class. db.t3.micro keeps the lab within the AWS free tier where eligible."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB for RDS."
  type        = number
  default     = 20
}

variable "student_ip_cidr" {
  description = "CIDR block (typically the student's single IP, e.g. 203.0.113.5/32) allowed to reach RDS on port 5432."
  type        = string
}

# --- dynamodb ---

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB tracking table."
  type        = string
  default     = "package_tracking"
}
