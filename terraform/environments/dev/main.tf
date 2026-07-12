data "aws_organizations_organization" "this" {}

module "transit_gateway" {
  source = "../../modules/transit-gateway"
  providers = {
    aws = aws.network
  }
  name              = "netops-tgw-dev"
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
  name                = "spoke-dev1-vpc"
  ipam_pool_id       = "ipam-pool-07627ea1fbb4208e5"
  netmask_length     = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6 # /28 subnets from /22 VPC

}


# Spoke Dev2 VPC — account SPOKE_DEV2_ACCOUNT_ID
module "vpc_spoke2" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.spoke2
  }
  name               = "spoke-prod-vpc"
  ipam_pool_id       = "ipam-pool-04540de906d50e885"
  netmask_length     = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6 # /28 subnets from /22 VPC
}

# VPC 2 Spoke Dev 2 - account SPOKE_DEV2_ACCOUNT_ID
module "vpc2_spoke2" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.spoke2
  }
  name               = "spoke-prod-vpc2"
  ipam_pool_id       = "ipam-pool-04540de906d50e885"
  netmask_length     = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6 # /28 subnets from /22 VPC
}

module "inspection_vpc" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.network
  }
  name = "inspection-vpc-dev"
  ipam_pool_id = "ipam-pool-04540de906d50e885"
  netmask_length = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6
}

module "eveng_vpc" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.eveng
  }
  name = "eveng vpc"
  ipam_pool_id = "ipam-pool-04540de906d50e885"
  netmask_length = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6
}