output "database_name" {
  description = "Glue Catalog database name for the lab dataset."
  value       = aws_glue_catalog_database.lab.name
}

output "table_name" {
  description = "Glue Catalog table name for tracking events."
  value       = aws_glue_catalog_table.tracking_events.name
}

output "workgroup_name" {
  description = "Athena workgroup name to run queries against."
  value       = aws_athena_workgroup.lab.name
}

output "resource_arn" {
  description = "Primary resource ARN for this module (the Athena workgroup)."
  value       = aws_athena_workgroup.lab.arn
}
