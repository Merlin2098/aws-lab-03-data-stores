variable "name_prefix" {
  description = "Prefix used for resource naming, derived from project_name and environment."
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used to keep the bucket name globally unique."
  type        = string
}

variable "bucket_suffix" {
  description = "Suffix appended to the generated data lake bucket name."
  type        = string
  default     = "datalake"
}

variable "enable_versioning" {
  description = "Whether to enable versioning on the data lake bucket. The lab exercise (docs/laboratorio_sesion_03_storage.md, section 5) asks for versioning explicitly."
  type        = bool
  default     = true
}

variable "lifecycle_transition_days" {
  description = "Days after which objects under raw/ transition to STANDARD_IA."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Whether Terraform may destroy the data lake bucket even when it contains objects. Keep true for dev/lab environments so `terraform destroy` works without manually emptying the bucket first (versioning being enabled otherwise blocks deletion of a non-empty bucket)."
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
