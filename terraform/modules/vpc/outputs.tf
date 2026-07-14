output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "tgw_subnet_ids" {
  value = aws_subnet.tgw_subnet[*].id
}

output "public_subnet" {
  value = aws_subnet.public_subnet[*].id
}

output "private_subnet" {
  value = aws_subnet.private_subnet[*].id
}

output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment.id
}

output "private_route_table" {
  value = aws_route_table.private_route_table.id
}

output "public_rt" {
  value = aws_route_table.public-rt.id
}