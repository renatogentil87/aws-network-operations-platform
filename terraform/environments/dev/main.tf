data "aws_organizations_organization" "this" {}

module "transit_gateway" {
  source = "../../modules/transit-gateway"
  providers = {
    aws = aws.network
  }
  name              = "netops-tgw-dev"
  amazon_side_asn   = 64512
  route_table_names = ["shared", "fullmesh", "firewall", "isolated"]
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
  transit_gateway_id = module.transit_gateway.tgw_id
}

module "tgw_routing" {
  source = "../../modules/tgw-routing"
  providers = {
    aws = aws.network
  }

  associations = {
    spoke1-to-fullmesh = {
      attachment_id  = module.vpc_spoke1.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
    }
    spoke2-to-fullmesh = {
      attachment_id  = module.vpc_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
    }
    spoke2-vpc2-to-fullmesh = {
      attachment_id  = module.vpc2_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
    }
    inspection-to-firewall = {
      attachment_id  = module.inspection_vpc.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["firewall"]
    }
    eveng-to-isolated = {
      attachment_id  = module.eveng_vpc.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["isolated"]
    }
    shared-vpc-to-shared-rt = {
      attachment_id = module.shared_vpc.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["shared"]
    }
  }
   ## Spoke to Firewall for return traffic
  propagations = {
    spoke1-into-firewall = {
      attachment_id  = module.vpc_spoke1.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["firewall"]
    }
    spoke2-into-firewall = {
      attachment_id  = module.vpc_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["firewall"]
    }
    spoke2-vpc2-into-firewall = {
      attachment_id  = module.vpc2_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["firewall"]
    }

    ## Spoke to fullmesh for fullmesh connectivity
    spoke1-into-fullmesh = {
      attachment_id  = module.vpc_spoke1.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
    }
    spoke2-into-fullmesh = {
      attachment_id  = module.vpc_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
    }
    spoke2-vpc2-into-fullmesh = {
      attachment_id  = module.vpc2_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
    }

    ### Spokes to Shared
    spoke1-into-shared = {
      attachment_id  = module.vpc_spoke1.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["shared"]
    }
    spoke2-into-shared = {
      attachment_id  = module.vpc_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["shared"]
    }
    spoke2-vpc2-into-shared = {
      attachment_id  = module.vpc2_spoke2.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["shared"]
    }

    ## Shared into fullmesh
    shared-into-fullmesh = {
      attachment_id = module.shared_vpc.tgw_attachment_id
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
    }
  }

  static_routes = {
    fullmesh-default-to-inspection = {
      destination = "0.0.0.0/0"
      route_table_id = module.transit_gateway.route_table_ids["fullmesh"]
      attachment_id = module.inspection_vpc.tgw_attachment_id
    }
    shared-default-to-inspection = {
      destination = "0.0.0.0/0"
      route_table_id = module.transit_gateway.route_table_ids["shared"]
      attachment_id = module.inspection_vpc.tgw_attachment_id
    }
  }
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
  transit_gateway_id = module.transit_gateway.tgw_id

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
  transit_gateway_id = module.transit_gateway.tgw_id

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
  transit_gateway_id = module.transit_gateway.tgw_id
}

module "shared_vpc" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.network
  }
  name = "shared_vpc"
  ipam_pool_id = "ipam-pool-04540de906d50e885"
  netmask_length = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6
  transit_gateway_id = module.transit_gateway.tgw_id
}

### INSPECTION VPC CONFIGURATION

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
  transit_gateway_id = module.transit_gateway.tgw_id
  tgw_default_route = false
  tgw_appliance_mode = true
}

resource "aws_eip" "eip" {
  provider = aws.network
  domain = "vpc"
  tags = { Name = "eip-inspection-vpc"}
}

resource "aws_nat_gateway" "natgw" {
  subnet_id = module.inspection_vpc.public_subnet[0]
  allocation_id = aws_eip.eip.id
  tags = {Name = "inspection-vpc-nat-gateway"}
}
resource "aws_internet_gateway" "internet_gateway" {
  provider = aws.network
  vpc_id = module.inspection_vpc.vpc_id
  tags = {
    Name = "inspection-internet-gateway"
  }
}
resource "aws_route" "inspection_private_to_natgw" {
  route_table_id = module.inspection_vpc.private_route_table
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.natgw.id
}

resource "aws_route" "public_route_to_igw" {
  route_table_id = module.inspection_vpc.public_rt
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

