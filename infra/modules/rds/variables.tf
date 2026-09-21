variable "name_prefix" {
  description = "Prefix used for resource naming, derived from project_name and environment."
  type        = string
}

variable "db_name" {
  description = "Name of the initial Postgres database."
  type        = string
  default     = "logistics"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "lab_admin"
}

variable "db_password" {
  description = "Master password for the RDS instance. Must be supplied via terraform.tfvars or TF_VAR_db_password, never hardcoded."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro keeps the lab within the AWS free tier where eligible."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "student_ip_cidr" {
  description = "CIDR block (typically the student's single IP, e.g. 203.0.113.5/32) allowed to reach RDS on port 5432. Required — the security group has no other ingress path."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for RDS-exported logs."
  type        = number
  default     = 7
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
