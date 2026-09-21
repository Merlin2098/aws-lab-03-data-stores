variable "name_prefix" {
  description = "Prefix used for resource naming, derived from project_name and environment."
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used to keep the bucket name globally unique."
  type        = string
}

variable "artifact_path" {
  description = "Path to the packaged runtime artifact produced by make package."
  type        = string
}

variable "artifact_bucket_suffix" {
  description = "Suffix appended to the generated artifact bucket name."
  type        = string
}

variable "artifact_bucket_force_destroy" {
  description = "Whether Terraform may destroy the artifact bucket even when it contains objects. Keep true for dev and sandbox environments."
  type        = bool
}

variable "enable_artifact_bucket_versioning" {
  description = "Whether to enable versioning on the artifact bucket. Defaults to false to keep dev environments cheap and easy to destroy."
  type        = bool
}

variable "execution_role_name" {
  description = "IAM role name for AWS data jobs."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for the data job execution role."
  type        = number
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
