output "endpoint" {
  description = "Connection endpoint (host:port) for the RDS instance."
  value       = aws_db_instance.lab.endpoint
}

output "port" {
  description = "Port the RDS instance listens on."
  value       = aws_db_instance.lab.port
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.lab.db_name
}

output "security_group_id" {
  description = "Security group ID restricting access to the student IP."
  value       = aws_security_group.rds.id
}

output "resource_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.lab.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for RDS PostgreSQL logs."
  value       = aws_cloudwatch_log_group.rds_postgresql.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for RDS PostgreSQL logs."
  value       = aws_cloudwatch_log_group.rds_postgresql.arn
}
