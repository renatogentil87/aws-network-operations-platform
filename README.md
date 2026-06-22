# AWS Network Operations Platform (ANOP)

A production-grade, multi-account, multi-region AWS networking platform using **Terraform** for infrastructure provisioning and a **Python CLI (`netops`)** for operations, validation, testing, drift detection, remediation, reporting, and operational maturity scoring.

## Goal

Build a Principal-level AWS Network Operations Platform supporting:
- Hundreds of AWS accounts
- Multiple AWS regions
- Enterprise change control (GitOps)
- Disaster recovery
- Operational excellence
- Platform engineering best practices

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Network Operations Platform                    │
├──────────────────────────────┬──────────────────────────────────────┤
│       TERRAFORM (IaC)        │          PYTHON (Operations)          │
├──────────────────────────────┼──────────────────────────────────────┤
│ • VPCs                       │ • netops inventory                    │
│ • Transit Gateway            │ • netops validate                     │
│ • Route Tables               │ • netops test                         │
│ • VPN                        │ • netops drift                        │
│ • Route53                    │ • netops recover                      │
│ • IAM                        │ • netops report                       │
│ • CloudWatch                 │ • netops score                        │
│ • Logging                    │ • netops chaos                        │
│ • EventBridge                │                                       │
│ • Systems Manager            │                                       │
│ • Multi-region architecture  │                                       │
└──────────────────────────────┴──────────────────────────────────────┘
```

## Phases

| # | Phase | Description |
|---|-------|-------------|
| 0 | Repository Foundation | Repo structure, CI/CD, state management |
| 1 | Network Foundation | VPCs, TGW, subnets, route tables |
| 2 | Multi-Region Resilience | Cross-region TGW peering, failover |
| 3 | Observability Platform | CloudWatch, Flow Logs, logging pipeline |
| 4 | Python CLI Framework | `netops` CLI skeleton with Click/Typer |
| 5 | Inventory Engine | Discover and catalog all network resources |
| 6 | Validation Framework | Validate configurations against policies |
| 7 | Automated Network Testing | Connectivity, latency, path validation |
| 8 | Drift Detection | Compare live state vs. Terraform state |
| 9 | Automated Recovery | Self-healing for known failure patterns |
| 10 | Chaos Engineering | Controlled failure injection |
| 11 | Operational Runbooks | SSM Automation documents |
| 12 | Reporting | Dashboards, PDFs, executive summaries |
| 13 | Operational Maturity Scoring | Score the platform against best practices |

## Repository Structure

```
aws-network-operations-platform/
├── terraform/
│   ├── modules/              # Reusable Terraform modules
│   │   ├── vpc/
│   │   ├── transit-gateway/
│   │   ├── route-tables/
│   │   ├── vpn/
│   │   ├── route53/
│   │   ├── iam/
│   │   ├── cloudwatch/
│   │   ├── logging/
│   │   ├── eventbridge/
│   │   └── systems-manager/
│   ├── environments/         # Per-environment configurations
│   │   ├── dev/
│   │   ├── test/
│   │   └── prod/
│   └── global/               # Cross-environment resources (state, IAM)
├── python/
│   ├── netops/               # CLI application package
│   │   ├── commands/         # CLI command implementations
│   │   ├── engines/          # Business logic engines
│   │   └── utils/            # Shared utilities
│   └── tests/                # Test suite
├── docs/
│   ├── phases/               # Phase-by-phase implementation plans
│   ├── architecture/         # Architecture decision records
│   └── runbooks/             # Operational runbooks
├── .github/
│   ├── workflows/            # GitHub Actions pipelines
│   └── PULL_REQUEST_TEMPLATE/
├── scripts/                  # Helper scripts (bootstrap, etc.)
└── configs/                  # Configuration files (linting, etc.)
```

## CI/CD Model (GitOps)

```
Feature Branch → PR → terraform plan + lint + security scan → Review → Merge
                                                                         ↓
                                                              terraform apply
                                                                         ↓
                                                              netops validate
                                                                         ↓
                                                              netops test
                                                                         ↓
                                                              netops report
```

### PR Pipeline
- `terraform fmt` / `terraform validate` / `terraform plan`
- `checkov` / `tfsec` (security scanning)
- `python lint` / `pytest`

### Merge Pipeline
- `terraform init` → `terraform plan` → `terraform apply`

### Post-Deployment
- `netops validate` → `netops test` → `netops report`

## State Management

- **Backend:** S3 + DynamoDB lock table
- **Separation:** By account × environment × region

## Environments

| Environment | Purpose |
|-------------|---------|
| `dev` | Development and experimentation |
| `test` | Integration testing and validation |
| `prod` | Production workloads |

## Getting Started

1. Read the phase plans in `docs/phases/`
2. Start with Phase 0 (Repository Foundation)
3. Each phase builds on the previous — follow sequentially

## License

Private — Internal Use Only
