resource "aws_glue_catalog_database" "lab" {
  name = replace("${var.name_prefix}_events", "-", "_")
}

resource "aws_glue_catalog_table" "tracking_events" {
  name          = "tracking_events"
  database_name = aws_glue_catalog_database.lab.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"     = "parquet"
    "has_encrypted_data" = "false"
  }

  storage_descriptor {
    location      = "s3://${var.datalake_bucket_name}/${var.data_prefix}"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "package_id"
      type = "string"
    }

    columns {
      name = "timestamp"
      type = "string"
    }

    columns {
      name = "status"
      type = "string"
    }

    columns {
      name = "city"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }

  partition_keys {
    name = "month"
    type = "string"
  }

  partition_keys {
    name = "day"
    type = "string"
  }
}

resource "aws_athena_workgroup" "lab" {
  name = "${var.name_prefix}-lab-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.datalake_bucket_name}/athena-results/"
    }
  }

  tags = var.common_tags
}
