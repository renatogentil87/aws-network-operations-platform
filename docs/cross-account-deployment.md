# Cross-Account Deployment Guide

## Overview

Terraform runs from the **Management account** (`MANAGEMENT_ACCOUNT_ID`) and assumes the
`NetOps-TerraformExecution` role into target accounts to deploy infrastructure.

```
Management Account (MANAGEMENT_ACCOUNT_ID)
  └── assumes role ──► Network Account      → TGW, RAM shares, Inspection VPC
  └── assumes role ──► Perimeter Account    → Ingress/Egress VPCs, Firewalls
  └── assumes role ──► SharedServices       → Shared Services VPC, Endpoints
  └── assumes role ──► SpokeDev1            → Dev workload VPCs
  └── assumes role ──► SpokeProd1           → Prod workload VPCs
```

## IAM Role (Deployed by LZA)

The role `NetOps-TerraformExecution` is defined in:
```
landing-zone-accelerator-on-aws/iam-config.yaml
```

It deploys to all accounts in these OUs:
- Infrastructure (Network, Perimeter, SharedServices)
- Workloads/Dev
- Workloads/Test
- Workloads/Prod

Trust policy allows only the Management account (`MANAGEMENT_ACCOUNT_ID`) to assume it.

## Terraform Provider Configuration

```hcl
# Management account (default — where pipeline/state lives)
provider "aws" {
  region = "eu-west-1"
}

# Network account — TGW, inspection, RAM shares
provider "aws" {
  alias  = "network"
  region = "eu-west-1"
  assume_role {
    role_arn     = "arn:aws:iam::${var.network_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }
}

# Spoke accounts — VPCs, attachments
provider "aws" {
  alias  = "spoke"
  region = "eu-west-1"
  assume_role {
    role_arn     = "arn:aws:iam::${var.spoke_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }
}
```

## Passing Providers to Modules

```hcl
module "transit_gateway" {
  source    = "../../modules/transit-gateway"
  providers = { aws = aws.network }
}

module "spoke_vpc" {
  source    = "../../modules/vpc"
  providers = { aws = aws.spoke }

  transit_gw_id = module.transit_gateway.tgw_id
}
```

## RAM Sharing (TGW to Spoke Accounts)

The TGW is created in the Network account. Spoke accounts see it via AWS RAM:

```hcl
# In transit-gateway module (Network account)
resource "aws_ram_resource_share" "tgw" {
  name                      = "tgw-share"
  allow_external_principals = false
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "org" {
  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}
```

Then in the spoke account, the VPC attachment references the shared TGW by ID:

```hcl
# In vpc module (Spoke account)
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gw_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.tgw[*].id
}
```

## Deployment Steps

1. **Push LZA changes** — commit `iam-config.yaml`, LZA pipeline creates the role in all target accounts
2. **Verify role exists** — `aws sts assume-role --role-arn arn:aws:iam::<ACCOUNT_ID>:role/NetOps-TerraformExecution --role-session-name test`
3. **Configure providers** in your environment `main.tf`
4. **Run Terraform** — `terraform plan` / `terraform apply` from Management account

## Onboarding a New Spoke Account

When LZA creates a new account, follow these steps to connect it to the transit network:

### Prerequisites (automatic)
- LZA deploys `NetOps-TerraformExecution` role to the new account
- LZA StackSet auto-deploys the NOTG spoke stack (via `customizations-config.yaml`)

### Step 1: Update SSM Parameter

Account IDs are stored in SSM Parameter Store (`/netops/config/accounts`) — never in GitHub.
The pipeline fetches this at build time to populate `terraform.tfvars`.

```bash
# Fetch current config
aws ssm get-parameter \
  --name "/netops/config/accounts" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region eu-west-1 > /tmp/accounts.tfvars

# Add the new account
echo 'spoke3_account_id = "111222333444"' >> /tmp/accounts.tfvars

# Update SSM
aws ssm put-parameter \
  --name "/netops/config/accounts" \
  --type SecureString \
  --value "$(cat /tmp/accounts.tfvars)" \
  --overwrite \
  --region eu-west-1

# Clean up
rm /tmp/accounts.tfvars
```

### Step 2: Add Terraform Code (in GitHub)

Add the provider in `terraform/environments/dev/providers.tf`:
```hcl
provider "aws" {
  alias  = "spoke3"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.spoke3_account_id}:role/NetOps-TerraformExecution"
    session_name = "terraform-netops"
  }
  default_tags { tags = { Project = "aws-network-operations-platform", ManagedBy = "terraform" } }
}
```

Add the variable in `terraform/environments/dev/variables.tf`:
```hcl
variable "spoke3_account_id" {
  description = "AWS Account ID for the new spoke account"
  type        = string
  sensitive   = true
}
```

Add the VPC module in `terraform/environments/dev/main.tf`:
```hcl
module "vpc_spoke3" {
  source = "../../modules/vpc"
  providers = { aws = aws.spoke3 }

  name               = "spoke3-vpc"
  ipam_pool_id       = "ipam-pool-XXXXXXXXXXXX"  # Use pool for the account's OU
  netmask_length     = 22
  availability_zones = ["eu-west-1a", "eu-west-1b"]
  tgw_subnet_newbits = 6  # /28 subnets for TGW ENIs

  notg_tags = {
    "Attach-to-tgw"  = "fullmesh"
    "Associate-with" = "fullmesh"
    "Propagate-to"   = "firewall"
  }
}
```

### Step 3: Push and Deploy

```bash
git add -A && git commit -m "feat: onboard spoke3 VPC" && git push origin main
```

The pipeline will:
1. Fetch account IDs from SSM (`/netops/config/accounts`)
2. Write `terraform.tfvars` in-memory
3. Run `terraform plan` / `apply`
4. Create VPC + subnets with NOTG tags
5. NOTG orchestrator detects the tags and auto-attaches to TGW

### IPAM Pool Reference

| OU | IPAM Pool ID | Description |
|----|-------------|-------------|
| Workloads/Dev | `ipam-pool-07627ea1fbb4208e5` | Dev LZA accounts |
| Workloads/Prod | `ipam-pool-04540de906d50e885` | Prod LZA accounts |

### Verify the Attachment

After the pipeline completes, verify the TGW attachment was created:
```bash
aws ec2 describe-transit-gateway-vpc-attachments \
  --filters "Name=state,Values=available" \
  --region eu-west-1 \
  --query "TransitGatewayVpcAttachments[*].{VpcId:VpcId,State:State,TgwId:TransitGatewayId}"
```

## Security Notes

- The role currently has `AdministratorAccess` — scope down to least privilege once modules are stable
- Session name `terraform-netops` aids CloudTrail attribution
- Future: replace Management account trust with GitHub Actions OIDC role for CI/CD pipeline
