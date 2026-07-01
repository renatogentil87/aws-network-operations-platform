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

module "vpc" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.spoke
  }

  name           = "spoke-dev-vpc"
  ipam_pool_id   = "ipam-pool-07627ea1fbb4208e5"
  netmask_length = 22
}

