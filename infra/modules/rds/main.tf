# lab-only: publicly_accessible = true + a security group scoped to a single
# student IP is a deliberate exception to "private by default" (AGENTS.md).
# It lets the student connect with a plain SQL client without a bastion or
# SSM port forwarding, which the lab exercise does not otherwise cover.
# Do not replicate this pattern for production-grade infrastructure.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "lab" {
  name       = "${var.name_prefix}-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  tags       = var.common_tags
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Allow Postgres access from the student IP only."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Postgres from student IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.student_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

resource "aws_db_instance" "lab" {
  identifier     = "${var.name_prefix}-lab-db"
  engine         = "postgres"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.lab.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true

  multi_az                        = false
  backup_retention_period         = 1
  skip_final_snapshot             = true
  deletion_protection             = false
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "rds_postgresql" {
  name              = "/aws/rds/instance/${aws_db_instance.lab.identifier}/postgresql"
  retention_in_days = var.log_retention_days
  tags              = var.common_tags
}
