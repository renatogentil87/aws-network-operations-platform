# Phase 6: Validation Framework

## Objective

Build the `netops validate` command — a policy-as-code framework that checks the live network state against a set of configurable rules and reports compliance/violations.

## Deliverables

1. **Rule engine** — Declarative rules (YAML) that define expected network state
2. **Built-in rule library** — Common best-practice checks out of the box
3. **Custom rules** — Extensible framework for organization-specific policies
4. **Severity levels** — Critical, High, Medium, Low findings
5. **Remediation hints** — Each violation includes a suggested fix
6. **Report output** — Summary table + detailed findings (json/table/csv)

## Detailed Implementation

### 1. Built-in Validation Rules

| Rule ID | Category | Check | Severity |
|---------|----------|-------|----------|
| NET-001 | Routing | No blackhole routes in TGW route tables | Critical |
| NET-002 | Routing | All VPC route tables have default route | High |
| NET-003 | Routing | TGW attachment subnets are /28 and dedicated | Medium |
| NET-004 | HA | NAT Gateways deployed in multiple AZs | High |
| NET-005 | HA | VPN tunnels — both tunnels UP | Critical |
| NET-006 | Security | No 0.0.0.0/0 in security groups (except ALB/NLB) | High |
| NET-007 | Security | Flow logs enabled on all VPCs | High |
| NET-008 | DNS | Route 53 health checks configured for failover records | High |
| NET-009 | DNS | TTL ≤ 60s for failover records | Medium |
| NET-010 | Tagging | All network resources tagged per standard | Medium |
| NET-011 | Endpoints | Gateway endpoints (S3, DynamoDB) present in all VPCs | Medium |
| NET-012 | Routing | No asymmetric routing paths between AZs | High |
| NET-013 | TGW | All spoke attachments associated to correct route table | Critical |
| NET-014 | TGW | Cross-region peering routes present and correct | High |
| NET-015 | Cost | Unused NAT Gateways (no traffic for 7 days) | Low |

### 2. Rule Definition Format (YAML)

```yaml
rules:
  - id: NET-001
    name: "No blackhole routes in TGW route tables"
    description: "TGW route tables must not contain blackhole routes (missing attachments)"
    category: routing
    severity: critical
    resource_type: transit-gateway-route-table
    check: "routes[?state=='blackhole'] | length(@) == 0"
    remediation: "Remove blackhole routes or re-attach the missing TGW attachment"
```

### 3. Command Interface

```bash
# Run all validations
netops validate

# Run specific category
netops validate --category routing
netops validate --category security

# Run specific rule
netops validate --rule NET-001

# Scope to account/region
netops validate --account prod --region ca-central-1

# Output with remediation hints
netops validate --show-remediation

# Fail on critical (for CI/CD pipeline)
netops validate --fail-on critical
```

### 4. Validation Report Output

```
┌─────────┬──────────────────────────────────┬──────────┬────────┐
│ Rule    │ Description                      │ Severity │ Status │
├─────────┼──────────────────────────────────┼──────────┼────────┤
│ NET-001 │ No blackhole routes in TGW       │ Critical │ ✅ PASS │
│ NET-002 │ Default routes in all VPC RTs    │ High     │ ✅ PASS │
│ NET-005 │ Both VPN tunnels UP              │ Critical │ ❌ FAIL │
│ NET-007 │ Flow logs enabled on all VPCs    │ High     │ ✅ PASS │
│ NET-010 │ Tagging compliance               │ Medium   │ ⚠️ WARN │
└─────────┴──────────────────────────────────┴──────────┴────────┘

Summary: 13 PASS | 1 FAIL | 1 WARN | 0 SKIP
```

### 5. CI/CD Integration

- `netops validate --fail-on critical` returns exit code 1 if any critical finding exists
- Used in post-deployment pipeline to gate promotions
- JSON output consumed by reporting engine (Phase 12)

## Acceptance Criteria

- [ ] All 15 built-in rules execute without errors
- [ ] Rules correctly identify violations in intentionally misconfigured test environment
- [ ] Custom rules can be added via YAML without code changes
- [ ] `--fail-on critical` returns correct exit code for CI/CD
- [ ] Output renders in all formats (table, json, csv)
- [ ] Execution completes within 3 minutes across full environment

## Dependencies

- Phase 5 complete (inventory engine provides resource data)
- Test environment with intentional misconfigurations for validation testing

## Estimated Effort

4–5 days
