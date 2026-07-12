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
