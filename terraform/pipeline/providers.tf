terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "aws-netops-platform-tfstate"
    key            = "pipeline/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-netops-platform-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project   = "aws-network-operations-platform"
      ManagedBy = "terraform"
      Component = "pipeline"
    }
  }
}
