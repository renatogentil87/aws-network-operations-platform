# Phase 5: Inventory Engine

## Objective

Build the `netops inventory` command — a comprehensive network resource discovery engine that catalogs all network components across accounts and regions into a queryable inventory.

## Deliverables

1. **Resource discovery** — Enumerate all network resources (VPCs, subnets, TGW, route tables, ENIs, etc.)
2. **Cross-account scanning** — Discover resources across all configured accounts
3. **Relationship mapping** — Build a graph of resource relationships (VPC → subnet → route table → TGW)
4. **Output formats** — JSON inventory file, terminal table, summary statistics
5. **Caching** — Local cache to avoid repeated API calls within a session
6. **Diff capability** — Compare current inventory with previous snapshot

## Detailed Implementation

### 1. Resources to Discover

| Category | Resources |
|----------|-----------|
| VPCs | VPCs, CIDR blocks, DHCP option sets, DNS settings |
| Subnets | Subnets, AZ mapping, available IPs, auto-assign public IP |
| Routing | Route tables, routes, associations, main route table |
| Transit Gateway | TGWs, attachments (VPC/peering/VPN), route tables, routes |
| Gateways | IGW, NAT GW, VGW, TGW |
| Connectivity | VPC peering, VPN connections, Direct Connect (future) |
| Endpoints | VPC endpoints (interface + gateway) |
| Security | Security groups (network-relevant), NACLs |
| DNS | Route 53 hosted zones, records, health checks |
| Load Balancers | NLBs (network-layer only) |
| ENIs | Elastic Network Interfaces (for troubleshooting) |

### 2. Command Interface

```bash
# Full inventory across all accounts and regions
netops inventory

# Scoped to specific account
netops inventory --account prod

# Scoped to specific region
netops inventory --region ca-central-1

# Specific resource type only
netops inventory --type vpc
netops inventory --type transit-gateway

# Save snapshot for diff comparison
netops inventory --save-snapshot

# Compare with previous snapshot
netops inventory --diff
```

### 3. Inventory Data Model

```
Inventory
├── accounts[]
│   ├── account_id
│   ├── account_name
│   └── regions[]
│       ├── region
│       ├── vpcs[]
│       │   ├── vpc_id, cidr, name, state
│       │   ├── subnets[]
│       │   ├── route_tables[]
│       │   ├── endpoints[]
│       │   └── security_groups[]
│       ├── transit_gateways[]
│       │   ├── tgw_id, asn, state
│       │   ├── attachments[]
│       │   ├── route_tables[]
│       │   └── peering_connections[]
│       ├── vpn_connections[]
│       ├── nat_gateways[]
│       └── route53_zones[]
└── metadata
    ├── scan_timestamp
    ├── scan_duration
    └── resource_counts
```

### 4. Execution Strategy

- Parallel API calls per account (ThreadPoolExecutor)
- Parallel regions within each account
- Rate limiting / exponential backoff for API throttling
- Progress bar showing discovery status

### 5. Snapshot & Diff

- Snapshots saved to `~/.netops/snapshots/YYYY-MM-DD-HHMMSS.json`
- Diff shows: added resources, removed resources, changed attributes
- Useful for: change validation, weekly audits, incident investigation

## Acceptance Criteria

- [ ] `netops inventory` discovers all network resources across all configured accounts
- [ ] Output renders correctly in table, json, and csv formats
- [ ] Cross-account role assumption works without manual intervention
- [ ] Snapshot save/load works correctly
- [ ] Diff correctly identifies added/removed/changed resources
- [ ] Execution completes within 2 minutes for 5 accounts × 2 regions
- [ ] API throttling is handled gracefully (retry with backoff)

## Dependencies

- Phase 4 complete (CLI framework, session management)
- Read-only IAM roles deployed in target accounts

## Estimated Effort

3–4 days
