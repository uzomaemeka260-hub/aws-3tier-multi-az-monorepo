terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tf_state" {
  bucket        = "uzoma-enterprise-tf-state-bucket-unique"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "enterprise-tf-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_acm_certificate" "https" {
  domain_name       = "devops.megatyreslimited.homes"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

output "acm_certificate_arn"        { value = aws_acm_certificate.https.arn }
output "acm_validation_name"        { value = tolist(aws_acm_certificate.https.domain_validation_options)[0].resource_record_name }
output "acm_validation_value"       { value = tolist(aws_acm_certificate.https.domain_validation_options)[0].resource_record_value }
output "state_bucket"               { value = aws_s3_bucket.tf_state.bucket }
output "dynamodb_table"             { value = aws_dynamodb_table.tf_locks.name }
