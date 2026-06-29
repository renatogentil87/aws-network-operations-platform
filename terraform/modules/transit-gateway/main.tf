terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_ec2_transit_gateway" "this" {
  description = "Central TGW"
  amazon_side_asn = var.amazon_side_asn
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = var.name
  }
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = toset(var.route_table_names)
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags ={
    Name = each.value
  }
}
