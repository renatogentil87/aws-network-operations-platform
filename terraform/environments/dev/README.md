# Dev Environment

Here you create the dev environment composition calling shared modules.

## Files to Create

- `main.tf` — Module calls (vpc, tgw, vpn, route53, cloudwatch, etc.)
- `variables.tf` — Environment-specific variable declarations
- `outputs.tf` — Exported resource IDs and endpoints
- `backend.tf` — S3 remote state backend configuration
- `terraform.tfvars` — Dev-specific values (CIDRs, instance sizes)

## Environment Characteristics

- Single region deployment
- Smaller CIDR blocks (/20 VPCs)
- Relaxed security controls for rapid iteration
- Single NAT Gateway (cost savings)
- Shorter log retention periods
