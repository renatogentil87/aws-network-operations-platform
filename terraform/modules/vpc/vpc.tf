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

  tags = merge(
    {
      Name = var.name
    },
    var.notg_vpc_tags
  )
}

# TGW attachment subnets — /28 dedicated for TGW ENIs
resource "aws_subnet" "tgw_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, var.tgw_subnet_newbits, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name = "${var.name}-tgw-${var.availability_zones[count.index]}"
    },
    var.notg_subnet_tags
  )
}

resource "aws_subnet" "public_subnet" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(aws_vpc.this.cidr_block, var.public_subnet, count.index + 2 )
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name = "${var.name}-public-subnet-${var.availability_zones[count.index]}"
    }
  )
}

resource "aws_subnet" "private_subnet" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(aws_vpc.this.cidr_block, var.private_subnet, count.index + 4)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name = "${var.name}-private-subnet-${var.availability_zones[count.index]}"
    }
  )
}
resource "aws_route_table" "private_route_table" {
    vpc_id = aws_vpc.this.id
    tags = merge({
      Name = "${var.name}-private-rt"
    })
}

resource "aws_route_table_association" "private_association" {
  count = length(var.availability_zones)
  route_table_id = aws_route_table.private_route_table.id
  subnet_id = aws_subnet.private_subnet[count.index].id
}
resource "aws_route_table_association" "public_association" {
  count = length(var.availability_zones)
  route_table_id = aws_route_table.public-rt.id
  subnet_id = aws_subnet.public_subnet[count.index].id
}
resource "aws_route" "private_subnet_route_to_tgw" {
  count = var.tgw_default_route ? 1: 0
  route_table_id = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id = var.transit_gateway_id
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tgw_attachment]
}
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    {
      Name = "${var.name}-public-rt"
    }
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attachment" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id = aws_vpc.this.id
  subnet_ids = aws_subnet.tgw_subnet[*].id
  appliance_mode_support = var.tgw_appliance_mode ? "enable" : "disable"
  tags = {
    Name = "${var.name}-tgw-attachment"
  }

}