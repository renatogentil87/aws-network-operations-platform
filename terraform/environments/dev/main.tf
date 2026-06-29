data "aws_organizations_organization" "this" {}

module "transit_gateway" {
  source = "../../modules/transit-gateway"
  providers = {
    aws = aws.network
  }
  name = "netops-tgw"
  amazon_side_asn = 64512
  route_table_names = ["shared", "fullmesh","firewall","spoke"]
  organization_arn = data.aws_organizations_organization.this.arn
}

