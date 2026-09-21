# No GSI on initial deploy: the "query packages by city" access pattern is
# the lab's Reto 3 (docs/laboratorio_sesion_03_storage.md, section 16),
# where the student designs and adds the GSI themselves.

resource "aws_dynamodb_table" "package_tracking" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "package_id"
  range_key    = "timestamp"

  attribute {
    name = "package_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = var.common_tags
}
