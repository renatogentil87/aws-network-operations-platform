# VPC Module

Here you create the VPC module to provision the core network foundation.

## Files to Create

- `vpc.tf` — Main VPC resource, subnets, gateways
- `variables.tf` — Input variables (CIDR, AZs, tags)
- `outputs.tf` — Exported VPC ID, subnet IDs, route table IDs

## What This Provisions

- VPC with DNS support enabled
- Public subnets (one per AZ) with Internet Gateway
- Private subnets (one per AZ) with NAT Gateway
- Transit subnets (for TGW attachments)
- Network ACLs per subnet tier
- Internet Gateway and NAT Gateway (one per AZ for HA)

## Design Notes

- Multi-AZ design (3 AZs by default)
- CIDR allocation from VPC IPAM pools
- Subnet CIDR calculation uses `cidrsubnet()` function
- Tags follow org-wide naming convention for automation
