terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = var.associations

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = var.propagations

  transit_gateway_attachment_id  = each.value.attachment_id
  transit_gateway_route_table_id = each.value.route_table_id
}

resource "aws_ec2_transit_gateway_route" "this" {
  for_each = var.static_routes

  destination_cidr_block         = each.value.destination
  transit_gateway_route_table_id = each.value.route_table_id
  transit_gateway_attachment_id  = lookup(each.value, "attachment_id", null)
  blackhole                      = lookup(each.value, "blackhole", false)
}
