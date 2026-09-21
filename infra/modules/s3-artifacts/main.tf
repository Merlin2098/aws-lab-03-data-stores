locals {
  bucket_name  = "${var.name_prefix}-${var.account_id}-${var.artifact_bucket_suffix}"
  artifact_key = "packages/${basename(var.artifact_path)}"
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.bucket_name
  force_destroy = var.artifact_bucket_force_destroy
  tags          = var.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = var.enable_artifact_bucket_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "artifact_bundle" {
  bucket = aws_s3_bucket.artifacts.id
  key    = local.artifact_key
  source = var.artifact_path
  etag   = filemd5(var.artifact_path)
  tags   = var.common_tags
}

data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "data_job_execution" {
  name               = "${var.name_prefix}-${var.execution_role_name}"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.data_job_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "artifact_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn]
  }
}

resource "aws_iam_role_policy" "artifact_access" {
  name   = "${var.name_prefix}-artifact-access"
  role   = aws_iam_role.data_job_execution.id
  policy = data.aws_iam_policy_document.artifact_access.json
}

resource "aws_cloudwatch_log_group" "data_jobs" {
  name              = "/aws/data-jobs/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  tags              = var.common_tags
}

data "aws_iam_policy_document" "cloudwatch_logs_access" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.data_jobs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs_access" {
  name   = "${var.name_prefix}-cloudwatch-logs-access"
  role   = aws_iam_role.data_job_execution.id
  policy = data.aws_iam_policy_document.cloudwatch_logs_access.json
}
