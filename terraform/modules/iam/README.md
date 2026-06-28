# IAM Module

Here you create the IAM module for cross-account access and CI/CD.

## Files to Create

- `roles.tf` — IAM roles for netops CLI cross-account access
- `oidc.tf` — OIDC provider for GitHub Actions
- `policies.tf` — Custom IAM policies
- `variables.tf` — Input variables
- `outputs.tf` — Role ARNs, OIDC provider ARN

## What This Provisions

- Cross-account IAM roles for netops CLI assume-role
- OIDC identity provider for GitHub Actions (keyless auth)
- Service-linked roles for AWS services
- Least-privilege policies scoped to network operations

## Design Notes

- No long-lived credentials; uses OIDC and STS
- Roles follow naming convention: `netops-{function}-role`
- Trust policies restrict to specific GitHub repos/branches
