output "bucket_name" {
  description = "Name of the data lake bucket."
  value       = aws_s3_bucket.datalake.bucket
}

output "bucket_arn" {
  description = "ARN of the data lake bucket."
  value       = aws_s3_bucket.datalake.arn
}

output "resource_arn" {
  description = "Primary resource ARN for this module (the data lake bucket)."
  value       = aws_s3_bucket.datalake.arn
}

output "raw_prefix" {
  description = "Key prefix for raw event data."
  value       = local.raw_prefix
}

output "curated_prefix" {
  description = "Key prefix for curated (Parquet, partitioned) event data."
  value       = local.curated_prefix
}
