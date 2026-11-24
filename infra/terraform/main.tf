terraform {
  required_version = "~> 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
  }
  # Supply environment-specific S3, KMS and DynamoDB settings using -backend-config.
  backend "s3" {}
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Use staging or production in the matching AWS account."
  }
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = { Product = "hasta", Environment = var.environment }
  }
}
