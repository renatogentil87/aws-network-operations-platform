# Phase 1: Network Foundation

## Objective

Provision the core network infrastructure — VPCs, subnets, Transit Gateway, route tables, and baseline connectivity — in a single primary region using reusable Terraform modules.

## Deliverables

1. **VPC module** — Configurable VPC with public/private/isolated subnet tiers, flow logs, and DNS settings
2. **Transit Gateway module** — Hub TGW with route tables, RAM sharing, and attachment management
3. **Route table module** — Spoke route tables with propagation and static route support
4. **Network account VPC** — Shared services / inspection VPC
5. **Spoke VPCs** — Workload VPCs (dev, test, prod) attached to TGW
6. **Connectivity validation** — Proof that spoke-to-spoke and spoke-to-shared-services routing works

## Detailed Implementation

### 1. VPC Module Design

Inputs:
- CIDR block (support IPAM integration later)
- Number of AZs (2 or 3)
- Subnet tiers: public, private, isolated (database), TGW attachment
- Enable/disable NAT Gateway, VPC endpoints, flow logs
- Tags (environment, cost center, owner)

Outputs:
- VPC ID, subnet IDs (by tier and AZ), route table IDs
- TGW attachment subnet IDs (dedicated /28 subnets for TGW)

Design decisions:
- Dedicated TGW attachment subnets (/28) — keeps TGW ENIs isolated from workloads
- Flow logs to CloudWatch Logs (S3 in Phase 3 for cost optimization)
- DNS resolution and hostnames enabled by default

### 2. Transit Gateway Module Design

Inputs:
- ASN (Amazon default or custom)
- Auto-accept shared attachments (true/false)
- Route table names and association/propagation rules
- RAM share target OUs or account IDs

Outputs:
- TGW ID, route table IDs, RAM share ARN

Route table strategy:
- `shared-services-rt` — Routes to all spokes + on-prem (future)
- `prod-rt` — Routes to shared services only (isolated from dev/test)
- `non-prod-rt` — Routes to shared services + between dev/test

### 3. Environment Configurations

```
terraform/environments/dev/
├── main.tf          # Module calls
├── variables.tf     # Environment-specific vars
├── outputs.tf       # Exported values
├── backend.tf       # S3 backend config
└── terraform.tfvars # Variable values
```

Each environment provisions:
- 1 workload VPC (attached to TGW)
- Association to appropriate TGW route table
- Route propagation per policy

### 4. Network Topology (Single Region)

```
                    ┌──────────────────┐
                    │  Transit Gateway  │
                    │   (ca-central-1)  │
                    └────────┬─────────┘
             ┌───────────────┼───────────────┐
             │               │               │
    ┌────────┴──────┐ ┌─────┴───────┐ ┌─────┴───────┐
    │  Shared Svcs  │ │   Prod VPC   │ │ Non-Prod VPC│
    │     VPC       │ │              │ │ (dev/test)  │
    │  10.0.0.0/16  │ │ 10.1.0.0/16 │ │ 10.2.0.0/16│
    └───────────────┘ └──────────────┘ └─────────────┘
```

### 5. CIDR Planning

| VPC | CIDR | Purpose |
|-----|------|---------|
| Shared Services | 10.0.0.0/16 | DNS, endpoints, inspection, tools |
| Production | 10.1.0.0/16 | Production workloads |
| Non-Production | 10.2.0.0/16 | Dev + Test workloads |
| Reserved | 10.3.0.0/16 – 10.255.0.0/16 | Future expansion |

## Acceptance Criteria

- [ ] VPC module provisions VPC with all subnet tiers in configurable AZs
- [ ] TGW module creates TGW, route tables, and RAM share
- [ ] Spoke VPCs attach to TGW with correct route table association
- [ ] EC2 instance in Prod VPC can reach Shared Services VPC via TGW
- [ ] EC2 instance in Prod VPC CANNOT reach Non-Prod VPC (isolation validated)
- [ ] All resources tagged per naming convention
- [ ] Terraform plan shows no drift after apply

## Dependencies

- Phase 0 complete (state backend, CI/CD)
- AWS accounts provisioned (Network hub + spoke accounts)
- CIDR ranges agreed

## Estimated Effort

3–5 days
