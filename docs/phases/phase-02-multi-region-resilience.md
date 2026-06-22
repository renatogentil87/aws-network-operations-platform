# Phase 2: Multi-Region Resilience

## Objective

Extend the network foundation to a second AWS region with cross-region Transit Gateway peering, establishing the infrastructure for disaster recovery and multi-region workloads.

## Deliverables

1. **Second region deployment** — Replicate VPC + TGW infrastructure in DR region
2. **TGW inter-region peering** — Establish peering between primary and DR Transit Gateways
3. **Cross-region routing** — Configure route tables for inter-region traffic flow
4. **DNS failover** — Route 53 health checks and failover routing for cross-region resolution
5. **Validation** — Prove cross-region connectivity and failover behavior

## Detailed Implementation

### 1. Region Strategy

| Region | Role | Purpose |
|--------|------|---------|
| ca-central-1 | Primary | Production traffic, Canadian data residency |
| us-east-1 | DR / Secondary | Disaster recovery, US-based workloads |

### 2. TGW Inter-Region Peering

- Create peering attachment from primary TGW to DR TGW
- Accept peering in DR region
- Add static routes in both TGW route tables pointing cross-region CIDRs to peering attachment
- No BGP over TGW peering (static routes only — AWS limitation)

Route table updates:
- Primary `shared-services-rt`: Add 10.128.0.0/9 → peering attachment (DR supernet)
- DR `shared-services-rt`: Add 10.0.0.0/9 → peering attachment (primary supernet)

### 3. DR Region CIDR Plan

| VPC | CIDR | Region |
|-----|------|--------|
| DR Shared Services | 10.128.0.0/16 | us-east-1 |
| DR Production | 10.129.0.0/16 | us-east-1 |
| DR Non-Production | 10.130.0.0/16 | us-east-1 |

Non-overlapping with primary region — enables full mesh routing.

### 4. Route 53 Configuration

- **Private Hosted Zones** — Associated with VPCs in both regions
- **Health Checks** — HTTPS probes against regional endpoints
- **Failover records** — Primary/secondary for shared services endpoints
- **Latency-based records** — For workloads that should route to nearest region

### 5. Multi-Region Terraform Structure

```
terraform/environments/
├── dev/
│   ├── ca-central-1/    # Primary region
│   └── us-east-1/       # DR region
├── test/
│   ├── ca-central-1/
│   └── us-east-1/
└── prod/
    ├── ca-central-1/
    └── us-east-1/
```

Each region has its own state file but shares module definitions.

### 6. Cross-Region Topology

```
    ca-central-1                              us-east-1
┌─────────────────┐    TGW Peering    ┌─────────────────┐
│  Transit GW     │◄─────────────────►│  Transit GW     │
│  (Primary)      │                    │  (DR)           │
├─────────────────┤                    ├─────────────────┤
│ Shared Svcs VPC │                    │ DR Shared VPC   │
│ Prod VPC        │                    │ DR Prod VPC     │
│ Non-Prod VPC    │                    │ DR Non-Prod VPC │
└─────────────────┘                    └─────────────────┘
```

## Acceptance Criteria

- [ ] DR region VPCs and TGW provisioned via same modules as primary
- [ ] TGW peering established and routes propagated
- [ ] EC2 in ca-central-1 Prod VPC can ping EC2 in us-east-1 DR Prod VPC
- [ ] Route 53 failover records resolve to DR when primary health check fails
- [ ] Failover time meets target (< 60 seconds with 30s TTL + fast health checks)
- [ ] Terraform state isolated per region

## Dependencies

- Phase 1 complete (primary region network foundation)
- DR region accounts/permissions provisioned
- RTO/RPO targets defined

## Estimated Effort

3–4 days
