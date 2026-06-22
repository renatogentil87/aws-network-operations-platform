# Phase 8: Drift Detection

## Objective

Build the `netops drift` command — detect when the live AWS network state has diverged from the expected state defined in Terraform or baseline configurations.

## Deliverables

1. **Terraform state drift** — Compare live resources against Terraform state
2. **Baseline drift** — Compare live state against a saved "golden" snapshot
3. **Configuration drift** — Detect changes made outside of IaC (console clicks, CLI)
4. **Drift classification** — Categorize drift by severity and risk
5. **Scheduled detection** — GitHub Actions workflow for daily drift checks
6. **Notification** — Alert on critical drift via SNS/Slack

## Detailed Implementation

### 1. Drift Detection Methods

| Method | What It Detects | How |
|--------|----------------|-----|
| Terraform plan | Resources changed outside Terraform | `terraform plan -detailed-exitcode` |
| Snapshot diff | Any resource change since last known-good state | Compare inventory snapshots |
| CloudTrail analysis | Who/when/what changed | Query CT events for mutating network API calls |

### 2. Resources to Monitor for Drift

| Resource | Critical Drift Examples |
|----------|----------------------|
| Route Tables | Route added/removed/changed without IaC |
| Security Groups | Rule added opening unexpected port |
| TGW Route Tables | Association/propagation changed |
| NACLs | Rule modified |
| VPC settings | DNS resolution disabled |
| NAT Gateways | Deleted or replaced |
| TGW Attachments | Detached or moved to wrong route table |

### 3. Command Interface

```bash
# Full drift check (Terraform + baseline)
netops drift

# Terraform state drift only
netops drift --method terraform

# Snapshot-based drift
netops drift --method snapshot

# CloudTrail-based (who changed what)
netops drift --method cloudtrail --days 7

# Scope to specific account/region
netops drift --account prod --region ca-central-1

# CI/CD mode — exit code 1 on critical drift
netops drift --fail-on critical
```

### 4. Drift Classification

| Severity | Examples | Action |
|----------|----------|--------|
| Critical | Route deleted, TGW detached, SG allows 0.0.0.0/0 | Immediate alert + auto-remediate (Phase 9) |
| High | Route table association changed, NAT GW replaced | Alert within 5 minutes |
| Medium | Tag changed, non-critical route added | Daily report |
| Low | Description updated, non-functional change | Weekly summary |

### 5. Drift Report Output

```
┌──────────┬──────────────────────────┬───────────┬──────────┬─────────────────────┐
│ Severity │ Resource                 │ Attribute │ Expected │ Actual              │
├──────────┼──────────────────────────┼───────────┼──────────┼─────────────────────┤
│ Critical │ rtb-0abc123 (prod-rt)    │ route     │ 10.0.0/8 │ MISSING             │
│ High     │ sg-0def456 (web-sg)      │ ingress   │ 443 only │ 443 + 22 (0.0.0.0) │
│ Medium   │ vpc-0ghi789 (prod-vpc)   │ tags      │ env=prod │ env=production      │
└──────────┴──────────────────────────┴───────────┴──────────┴─────────────────────┘

Drift Summary: 1 Critical | 1 High | 1 Medium | 0 Low
Last clean state: 2026-06-20 03:00:00 UTC
```

### 6. Scheduled Drift Detection (GitHub Actions)

```yaml
# .github/workflows/drift-check.yml
name: Daily Drift Detection
on:
  schedule:
    - cron: '0 6 * * *'  # 6 AM UTC daily
jobs:
  drift:
    steps:
      - netops drift --fail-on critical --output json
      - notify on failure
```

### 7. CloudTrail Integration

Query CloudTrail for mutating network API calls not made by the Terraform CI/CD role:
- `CreateRoute` / `DeleteRoute` / `ReplaceRoute`
- `AuthorizeSecurityGroupIngress` / `RevokeSecurityGroupIngress`
- `AssociateTransitGatewayRouteTable` / `DisassociateTransitGatewayRouteTable`
- `CreateNatGateway` / `DeleteNatGateway`

If the caller ARN is NOT the CI/CD role → flag as out-of-band change.

## Acceptance Criteria

- [ ] Terraform-based drift detection correctly identifies manual changes
- [ ] Snapshot diff correctly shows added/removed/changed resources
- [ ] CloudTrail analysis identifies out-of-band changes and their authors
- [ ] Drift severity classification matches defined rules
- [ ] Scheduled workflow runs daily and alerts on critical drift
- [ ] Exit code 1 returned for CI/CD gating when critical drift exists

## Dependencies

- Phase 5 complete (inventory snapshots for baseline comparison)
- Phase 0 complete (Terraform state accessible)
- CloudTrail enabled in all accounts

## Estimated Effort

3–4 days
