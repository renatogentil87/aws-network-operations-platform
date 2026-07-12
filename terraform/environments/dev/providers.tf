terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider — Management account (where state and pipeline live)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}

# Network account — TGW, inspection VPC, RAM shares
provider "aws" {
  alias  = "network"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.network_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}

# Perimeter account — Ingress/Egress VPCs, firewalls
provider "aws" {
  alias  = "perimeter"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.perimeter_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}

# SharedServices account — Shared VPC, endpoints, DNS
provider "aws" {
  alias  = "shared_services"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.shared_services_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}

# Spoke Dev1 account — Workload VPCs
provider "aws" {
  alias  = "spoke"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.spoke_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}

# Spoke Dev2 account — Workload VPCs
provider "aws" {
  alias  = "spoke2"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.spoke2_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}

## Eveng Account
provider "aws" {
  alias  = "eveng"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.eveng_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }

  default_tags {
    tags = {
      Project     = "aws-network-operations-platform"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}
