locals {
  bucket_name    = "${var.name_prefix}-${var.account_id}-${var.bucket_suffix}"
  raw_prefix     = "raw/events/"
  curated_prefix = "curated/events/"
}

resource "aws_s3_bucket" "datalake" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = var.common_tags
}

resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    id     = "raw-transition-to-ia"
    status = "Enabled"

    filter {
      prefix = local.raw_prefix
    }

    transition {
      days          = var.lifecycle_transition_days
      storage_class = "STANDARD_IA"
    }
  }
}
