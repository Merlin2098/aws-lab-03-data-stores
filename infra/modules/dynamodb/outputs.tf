output "table_name" {
  description = "Name of the DynamoDB table."
  value       = aws_dynamodb_table.package_tracking.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table."
  value       = aws_dynamodb_table.package_tracking.arn
}

output "resource_arn" {
  description = "Primary resource ARN for this module (the DynamoDB table)."
  value       = aws_dynamodb_table.package_tracking.arn
}
