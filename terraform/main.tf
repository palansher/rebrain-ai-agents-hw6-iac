# Учебный модуль Launch Control. plan.json снят заранее (terraform show -json tfplan),
# облачный аккаунт для задания не нужен - разбирается готовый план.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_db_instance" "launch_manifest" {
  identifier           = "launch-manifest"
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.medium"
  allocated_storage    = 50
  skip_final_snapshot  = true
  deletion_protection  = false
  backup_retention_period = 0
}

resource "aws_security_group" "api" {
  name = "launch-control-api"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "api" {
  name   = "launch-control-api"
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["*"], Resource = ["*"] }] })
}
