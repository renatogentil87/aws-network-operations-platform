# Configuration Files

Here you create YAML configuration files for the netops platform.

## Files to Create

- `accounts.yaml` — Account IDs, IAM roles, regions per account
- `networks.yaml` — CIDR plan, VPC names, subnet allocations
- `thresholds.yaml` — Scoring thresholds (pass/warn/fail levels)
- `gns3.yaml` — GNS3 server endpoints, router inventory, expected BGP peers

## Design Notes

- All configs loaded by `python/netops/utils/config.py`
- YAML chosen for human readability and comments
- Environment-specific overrides via env var or CLI flag
- Sensitive values (account IDs) kept here; secrets in SSM Parameter Store
