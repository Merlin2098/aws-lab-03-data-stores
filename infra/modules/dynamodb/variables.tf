variable "table_name" {
  description = "Name of the DynamoDB table."
  type        = string
  default     = "package_tracking"
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
