# Backend configuration for the global/bootstrap workspace.

terraform {
  backend "s3" {
    bucket         = "aws-netops-platform-tfstate"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-netops-platform-tfstate-lock"
    encrypt        = true
  }
}

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
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "global"
    }
  }
}
