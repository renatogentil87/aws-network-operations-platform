# AWS Network Operations Platform (ANOP)

## Architecture — Two Repos, Three Layers

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AWS Organization                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  LAYER 1: GOVERNANCE (LZA repo)                                         │
│  Pipeline: CodePipeline (managed by LZA installer)                      │
│  ───────────────────────────────────────────                            │
│  • Account lifecycle (create, move, suspend)                            │
│  • OUs, SCPs, RCPs, Declarative Policies                               │
│  • Security services (GuardDuty, Security Hub, Config, CloudTrail)      │
│  • IPAM pool hierarchy (consumed by Terraform via data sources)         │
│  • IAM baseline (Identity Center, permission sets)                      │
│  • Tagging & backup policies                                            │
│                                                                         │
│  LAYER 2: INFRASTRUCTURE (this repo — Terraform)                        │
│  Pipeline: GitHub Actions → OIDC → Terraform Apply                      │
│  ───────────────────────────────────────────                            │
│  • Transit Gateway + route tables                                       │
│  • VPCs (endpoints, ingress, egress, inspection, shared-services)       │
│  • Network Firewall                                                     │
│  • VPN / Direct Connect / Cloud WAN                                     │
│  • Route53 (private zones, resolvers)                                   │
│  • NAT Gateways, Internet Gateways                                      │
│  • VPC endpoints                                                        │
│  • CloudWatch (network alarms, dashboards)                              │
│  • EventBridge (auto-remediation triggers)                              │
│                                                                         │
│  LAYER 3: OPERATIONS (this repo — Python CLI)                           │
│  Pipeline: GitHub Actions (post-deploy validation)                      │
│  ───────────────────────────────────────────                            │
│  • netops inventory  — discover all network resources                   │
│  • netops validate   — check route symmetry, blackholes, SGs           │
│  • netops test       — connectivity tests, BGP route checks (GNS3)     │
│  • netops drift      — compare Terraform state vs live AWS             │
│  • netops recover    — auto-remediate (restart tunnels, fix routes)     │
│  • netops chaos      — inject failures (kill VPN, blackhole routes)     │
│  • netops report     — generate HTML/PDF reports                        │
│  • netops score      — operational maturity scoring                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## How Terraform Consumes LZA Resources

LZA creates the organizational foundation. Terraform references it:

```hcl
# Terraform reads IPAM pools created by LZA
data "aws_vpc_ipam_pool" "dev" {
  filter {
    name   = "tag:Name"
    values = ["AWSAccelerator-eu-west-1-ipam-workloads-dev-pool"]
  }
}

# Terraform reads account IDs from AWS Organizations (created by LZA)
data "aws_organizations_organization" "org" {}

# Terraform assumes cross-account roles (baseline created by LZA)
provider "aws" {
  alias  = "network"
  assume_role { role_arn = "arn:aws:iam::${var.network_account_id}:role/NetOps-TerraformExecution" }
}
```

## Pipelines

| Pipeline | Trigger | Tool | Responsibility |
|----------|---------|------|----------------|
| LZA | Push to LZA CodeCommit | CodePipeline | Governance, accounts, SCPs |
| Terraform | PR merge to `main` in this repo | GitHub Actions | Network infrastructure |
| Python | Post-Terraform-apply | GitHub Actions | Validation, testing, reporting |

## Getting Started

1. **LZA is already deployed** — it manages accounts, OUs, SCPs, IPAM
2. **Start with Phase 0** — set up Terraform backend (S3 + DynamoDB in Management account)
3. **Phase 1** — deploy TGW + first VPC using IPAM pools from LZA
4. **Phase 4** — build `netops` CLI to validate what Terraform deployed

See `docs/phases/` for detailed specs on each phase.
