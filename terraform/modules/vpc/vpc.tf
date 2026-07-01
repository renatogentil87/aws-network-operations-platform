terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_vpc_ipam_pool" "dev" {
  filter {
    name   = "description"
    values = ["IP regional pool allocation for Dev LZA accounts"]
  }
}

resource "aws_vpc" "this" {
  ipv4_ipam_pool_id = data.aws_vpc_ipam_pool.dev.id
  ipv4_netmask_length = 22
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "spoke-dev-vpc"
  }
}