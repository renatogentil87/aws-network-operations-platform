data "aws_organizations_organization" "this" {}

module "transit_gateway" {
  source = "../../modules/transit-gateway"
  providers = {
    aws = aws.network
  }
  name              = "netops-tgw"
  amazon_side_asn   = 64512
  route_table_names = ["shared", "fullmesh", "firewall", "spoke"]
  organization_arn  = data.aws_organizations_organization.this.arn
}

# Spoke Dev1 VPC — account SPOKE_DEV1_ACCOUNT_ID
module "vpc_spoke1" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.spoke
  }
  name               = "spoke-dev1-vpc"
  ipam_pool_id       = "ipam-pool-07627ea1fbb4208e5"
  netmask_length     = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6 # /28 subnets from /22 VPC

  notg_vpc_tags = {
    "Associate-with" = "fullmesh"
    "Propagate-to"   = "firewall"
  }

  notg_subnet_tags = {
    "Attach-to-tgw" = "fullmesh"
  }
}

# Spoke Dev2 VPC — account SPOKE_DEV2_ACCOUNT_ID
module "vpc_spoke2" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.spoke2
  }
  name               = "spoke-dev2-vpc"
  ipam_pool_id       = "ipam-pool-04540de906d50e885"
  netmask_length     = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6 # /28 subnets from /22 VPC

  notg_vpc_tags = {
    "Associate-with" = "fullmesh"
    "Propagate-to"   = "firewall"
  }

  notg_subnet_tags = {
    "Attach-to-tgw" = "fullmesh"
  }
}
