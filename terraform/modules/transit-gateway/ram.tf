
resource "aws_ram_resource_share" "tgw" {
  name = "${var.name}-share"
  allow_external_principals = false
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "org" {
  principal = var.organization_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}