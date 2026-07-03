# IP Address Allocation Strategy for Enterprise Cloud Networks: A Complete Guide to AWS IPAM

If you've ever inherited a cloud environment where every team picked their own CIDR block, you know the pain. Overlapping addresses between production and DR. A /16 VPC for a workload that uses 12 hosts. No room to grow because someone allocated 10.0.0.0/8 to a single region.

IP address planning isn't glamorous, but it's the single decision that's hardest to change once you've deployed workloads on top of it. Get it wrong, and you'll spend years working around it.

Here's how enterprise organizations design their IP allocation strategy — and how AWS IPAM turns that strategy into an automated, enforceable system.

---

## Why CIDR Planning Matters at Scale

In a single-account, single-VPC world, you pick a /16 and move on. But when you're operating across:

- 50–500 AWS accounts
- Multiple regions (primary + DR)
- Hybrid connectivity (Direct Connect to on-premises)
- Environment isolation (dev, test, staging, prod)
- Shared services, perimeters, and inspection VPCs

...you need an addressing scheme that is:

1. **Hierarchical** — Summarizable at each level for clean routing
2. **Non-overlapping** — No CIDR conflicts between any VPCs that might need to communicate
3. **Right-sized** — Not wasting address space on environments that don't need it
4. **Extensible** — Room to add regions, accounts, and environments without re-architecting

---

## The Hierarchical CIDR Model

The most effective pattern is a **4-tier hierarchy**:

```
Level 0 — Global Supernet
  └── Level 1 — Regional Pools
        └── Level 2 — Environment Pools (Dev, Test, Prod, Shared)
              └── Level 3 — VPC Allocations
```

Here's a real-world example using 10.0.0.0/8:

```
10.0.0.0/8 — Global Pool (Enterprise-wide)
│
├── 10.0.0.0/12 — eu-west-1 (Primary Region)
│   ├── 10.0.0.0/20  — Ingress/Perimeter
│   ├── 10.0.16.0/24 — Egress
│   ├── 10.0.17.0/24 — Inspection (Network Firewall)
│   ├── 10.0.20.0/22 — Endpoints (PrivateLink)
│   ├── 10.0.24.0/21 — Shared Services
│   ├── 10.4.0.0/14  — Workloads Dev (allocate /22 per VPC)
│   ├── 10.8.0.0/14  — Workloads Test (allocate /22 per VPC)
│   └── 10.12.0.0/14 — Workloads Prod (allocate /22 per VPC)
│
├── 10.16.0.0/12 — ca-central-1 (DR Region)
│   └── (same structure)
│
└── 172.16.0.0/12 — On-Premises (reserved, non-AWS)
```

Notice:
- **Infrastructure VPCs** (ingress, egress, inspection) are small (/20–/24) because they have few hosts — mostly ENIs for gateways and firewalls
- **Workload pools** are large (/14) because they'll contain dozens of VPCs over time
- **Individual workload VPCs** get a /22 (1,024 addresses) — enough for 3 AZs × multiple subnet tiers
- **On-premises space** is reserved as a custom allocation to prevent conflicts

---

## Sizing Guide: How Much Space Does Each Environment Need?

| VPC Type | Recommended Size | Why |
|----------|-----------------|-----|
| Workload (Dev) | /22 – /24 | Few instances, single NAT, limited subnets |
| Workload (Prod) | /20 – /22 | Multi-AZ, more hosts, room for auto-scaling |
| Shared Services | /21 – /20 | DNS resolvers, endpoints, AD, tooling |
| Inspection/Firewall | /24 – /28 | Only needs ENIs for firewall endpoints |
| Transit/Endpoints | /22 | VPC endpoints consume one ENI per AZ per service |
| Ingress (ALB/NLB) | /20 | Public subnets need room for EIP allocation |
| Egress (NAT) | /24 | NAT Gateways + routing — minimal hosts |

**Rule of thumb:** Dedicated TGW attachment subnets should be /28 — they only hold the Transit Gateway ENI and nothing else. Don't waste a /24 on a TGW subnet.

---

## AWS IPAM: From Strategy to Enforcement

A strategy on paper is worthless if teams can bypass it. AWS VPC IPAM makes your allocation plan **enforceable**.

### 1. Create the Hierarchy as IPAM Pools

```
IPAM
└── Private Scope
    └── Global Pool (10.0.0.0/8)
        ├── Regional Pool: eu-west-1 (10.0.0.0/12)
        │   ├── Pool: Dev Workloads (10.4.0.0/14)
        │   ├── Pool: Test Workloads (10.8.0.0/14)
        │   ├── Pool: Prod Workloads (10.12.0.0/14)
        │   ├── Pool: Shared Services (10.0.24.0/21)
        │   └── Pool: Inspection (10.0.17.0/24)
        └── Regional Pool: ca-central-1 (10.16.0.0/12)
            └── ...
```

### 2. Share Pools with Target Accounts via RAM

Each IPAM pool is shared with specific OUs or accounts using AWS Resource Access Manager:
- Dev pool → shared with `Workloads/Dev` OU
- Prod pool → shared with `Workloads/Prod` OU
- Inspection pool → shared with Network account only

Teams can only allocate from *their* pool. A developer can't accidentally grab production address space.

### 3. Set Allocation Rules

- Maximum netmask: /22 (prevents someone grabbing a /16)
- Required tags: `Environment=dev` must be present
- Locale enforcement: Pool locked to a specific region

Allocation rules don't block VPC creation — they flag resources as non-compliant if they violate the rule, giving you governance visibility.

### 4. VPCs Request CIDRs from IPAM at Creation Time

```hcl
resource "aws_vpc" "workload" {
  ipv4_ipam_pool_id   = "ipam-pool-0abc123def456"
  ipv4_netmask_length = 22
}
```

No hardcoded CIDRs. IPAM assigns the next available /22 from the pool. No conflicts. No spreadsheets. No Slack messages asking "what CIDR can I use?"

---

## Architecture: IPAM in a Multi-Account Organization

```
┌──────────────────────────────────────────────────────────────┐
│                    IPAM Delegated Admin                        │
│                    (Network Account)                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   IPAM Instance                                              │
│   ├── Private Scope                                          │
│   │   └── Global Pool (10.0.0.0/8)                          │
│   │       ├── Regional Pool: eu-west-1                       │
│   │       │   ├── Dev Pool ──── RAM Share ──→ Dev OU         │
│   │       │   ├── Prod Pool ─── RAM Share ──→ Prod OU        │
│   │       │   └── Infra Pool ── RAM Share ──→ Network Acct   │
│   │       └── Regional Pool: ca-central-1                    │
│   │           └── (same structure)                           │
│   └── Public Scope                                           │
│       └── BYOIP Pools (if applicable)                        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Dev Account │   │ Prod Account │   │Network Acct  │
│              │   │              │   │              │
│ VPC: /22     │   │ VPC: /20     │   │ VPC: /24     │
│ (from Dev    │   │ (from Prod   │   │ (from Infra  │
│  Pool)       │   │  Pool)       │   │  Pool)       │
└──────────────┘   └──────────────┘   └──────────────┘
```

**Key design decisions:**

- **Delegate IPAM administration** to your Network account — don't run it from the management account
- **One IPAM instance per organization** — it supports multiple operating regions
- **RAM sharing at the OU level**, not per-account — new accounts automatically inherit pool access
- **SCP enforcement** — Create an SCP that requires VPCs to use IPAM pools, preventing teams from creating VPCs with arbitrary CIDRs

---

## Hybrid Considerations

If you have on-premises data centers connected via Direct Connect or VPN, you **must** reserve their CIDRs in IPAM using custom allocations:

```
IPAM Pool: Global (10.0.0.0/8)
  ├── Custom Allocation: On-Premises DC1 (172.16.0.0/12) — RESERVED
  ├── Custom Allocation: On-Premises DC2 (192.168.0.0/16) — RESERVED
  └── Regional Pool: eu-west-1 (10.0.0.0/12) — Available for AWS
```

This prevents AWS resources from being allocated CIDRs that overlap with your corporate network. IPAM monitors and flags any conflicts.

For organizations going through **mergers and acquisitions**, use separate IPAM private scopes for each entity's overlapping address space. This gives you visibility into both addressing plans without generating false overlap alarms, while you plan the integration.

---

## Subnet Tier Design Within a VPC

Once IPAM allocates a /22 to your VPC, you need to divide it into subnets. The standard enterprise pattern:

```
VPC: 10.4.0.0/22 (1,024 addresses)
│
├── Public Subnets (ALB, NAT GW)
│   ├── AZ-a: 10.4.0.0/26   (64 addresses)
│   ├── AZ-b: 10.4.0.64/26  (64 addresses)
│   └── AZ-c: 10.4.0.128/26 (64 addresses)
│
├── Private/App Subnets (EC2, ECS, Lambda)
│   ├── AZ-a: 10.4.1.0/24   (256 addresses)
│   ├── AZ-b: 10.4.2.0/24   (256 addresses)
│   └── AZ-c: 10.4.3.0/24   (256 addresses — reserved for growth)
│
├── Data Subnets (RDS, ElastiCache)
│   ├── AZ-a: 10.4.0.192/26 (64 addresses)
│   ├── AZ-b: 10.4.3.0/26   (64 addresses)
│   └── AZ-c: 10.4.3.64/26  (64 addresses)
│
└── TGW Attachment Subnets
    ├── AZ-a: 10.4.3.192/28 (16 addresses)
    ├── AZ-b: 10.4.3.208/28 (16 addresses)
    └── AZ-c: 10.4.3.224/28 (16 addresses)
```

**Design principles:**
- Public subnets are small — you rarely need more than a handful of EIPs or ALB ENIs
- App subnets are the largest — this is where auto-scaling and container workloads live
- Data subnets are medium — databases don't scale horizontally as aggressively
- TGW subnets are minimal /28 — literally just one ENI per AZ

---

## Common Mistakes I See

1. **Starting with /16 VPCs everywhere** — You'll exhaust 10.0.0.0/8 with just 256 VPCs. Use /22 or /20 for workloads.

2. **No room between pools** — If you allocate 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16 sequentially, you can't expand the first pool later. Leave gaps between allocations.

3. **Flat structure** — A single pool with all VPCs makes routing summarization impossible. You can't create a route that says "all dev traffic goes here" if dev CIDRs are scattered across the address space.

4. **Forgetting TGW subnet sizing** — TGW attachment subnets don't need a /24. Use /28. That saves 240 addresses per VPC × 3 AZs.

5. **Not reserving on-premises space** — First VPN connection goes up, routing breaks because the VPC CIDR overlaps with corporate 10.x.x.x space.

6. **Ignoring IPv6** — If you're building greenfield, plan for dual-stack from day one. It's far easier than retrofitting later.

7. **No SCP enforcement** — Without an SCP requiring IPAM pool usage, one team creating a VPC with a hardcoded CIDR can blow up your entire routing design.

8. **Over-allocating to non-production** — Dev doesn't need the same address space as production. A /24 dev VPC is perfectly fine for most workloads.

---

## Quick Reference: Sizing Recommendations

| Decision | Recommendation |
|----------|---------------|
| Global address space | 10.0.0.0/8 (or BYOIP if enterprise owns public space) |
| Regional allocation | /12 per region (supports 1M+ addresses per region) |
| Environment pools | /14 per environment (Dev, Test, Prod) |
| Workload VPCs | /22 for standard, /20 for large production |
| Infrastructure VPCs | /24 for inspection/egress, /20 for ingress |
| App/Private subnets | /24 per AZ |
| Data subnets | /26 per AZ |
| Public subnets | /26 per AZ |
| TGW attachment subnets | /28 per AZ |
| IPAM delegation | Network account as delegated admin |
| Pool sharing | RAM share to OUs, not individual accounts |
| Enforcement | SCP requiring VPCs to use IPAM pools |

---

## Final Thought

Your IP addressing plan is the foundation that Transit Gateways, route tables, firewalls, and DNS all build on top of. It's the one decision that touches every workload, every account, and every network path in your environment.

Take the time to design it properly — you'll thank yourself in 2 years when the fifth business unit onboards and you don't have to re-IP anything.

---

*How does your organization handle CIDR planning? Are you using IPAM or still managing spreadsheets? I'd love to hear what's working (or not) for you.*

#AWS #Networking #CloudNetworking #IPAM #CIDR #IPv4 #EnterpriseArchitecture #InfrastructureAsCode #NetworkEngineering #VPC #TransitGateway
