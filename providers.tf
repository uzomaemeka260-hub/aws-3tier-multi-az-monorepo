terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 🟢 ADDED THIS BLOCK RIGHT HERE:
  # This tells Terraform to store your state file in S3 and use DynamoDB for locking.
  backend "s3" {
    bucket         = "uzoma-enterprise-tf-state-bucket-unique" # Must be a globally unique name across all of AWS
    key            = "production/3tier-vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "enterprise-tf-state-locks" # Enforces absolute state locking so code doesn't corrupt
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

