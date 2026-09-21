variable "name_prefix" {
  description = "Prefix used for resource naming, derived from project_name and environment."
  type        = string
}

variable "datalake_bucket_name" {
  description = "Name of the S3 data lake bucket (from the s3-datalake module)."
  type        = string
}

variable "datalake_bucket_arn" {
  description = "ARN of the S3 data lake bucket (from the s3-datalake module)."
  type        = string
}

variable "data_prefix" {
  description = "Key prefix where the queryable Parquet event data lives (from the s3-datalake module). Points at raw_prefix: this lab has no transformation step that populates a separate curated/ layer."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
