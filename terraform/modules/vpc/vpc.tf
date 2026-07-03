terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_vpc" "this" {
  ipv4_ipam_pool_id    = var.ipam_pool_id
  ipv4_netmask_length  = var.netmask_length
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.name
  }
}

# TGW attachment subnets — /28 dedicated for TGW ENIs
resource "aws_subnet" "tgw" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, var.tgw_subnet_newbits, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name = "${var.name}-tgw-${var.availability_zones[count.index]}"
    },
    var.notg_tags
  )
}
