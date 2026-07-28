# AWS Network Operations Platform

A production-grade hybrid network operations platform combining cloud infrastructure (Terraform), network automation (Python/Netmiko/Jinja2), and an MPLS service provider lab environment. Built to demonstrate Principal Network Architect-level skills across AWS networking, protocol design, and programmability.

---

## What This Is

This platform manages the full lifecycle of hybrid network operations across a multi-account AWS environment connected to on-premises infrastructure. It combines:

- **Infrastructure-as-Code (Terraform)** — multi-account AWS networking with centralized inspection
- **Network Automation (Python)** — configuration management, state validation, and drift detection
- **MPLS SP Lab (GNS3)** — 20-router service provider topology for protocol design and testing

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Hybrid Network Operations Platform                     │
├─────────────────┬───────────────────────────────┬───────────────────────┤
│   Terraform     │          Python               │     Operations        │
│  (Cloud Infra)  │  (Automation + Validation)    │     (Runbooks)        │
├─────────────────┼───────────────────────────────┼───────────────────────┤
│ • TGW           │ • Router config via Netmiko   │ • BGP flap response   │
│ • VPC + Subnets │ • Jinja2 templates            │ • VPN tunnel down     │
│ • Network FW    │ • AWS drift detection         │ • Route leak          │
│ • IPAM          │ • OSPF/LDP/BGP collectors     │   detection           │
│ • Multi-account │ • Health check validators     │                       │
│ • NAT/IGW       │ • Config backup               │                       │
│ • RAM shares    │ • GNS3 telnet automation      │                       │
└─────────────────┴───────────────────────────────┴───────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │  Terraform State   │
                    │ (Source of Truth)  │
                    │   S3 Backend       │
                    └───────────────────┘
```

---

## Repository Structure

```
├── terraform/                      Cloud infrastructure (CI/CD pipeline active)
│   ├── modules/                    Reusable modules (VPC, TGW, EC2, TGW-routing)
│   ├── environments/dev/           Environment composition (main.tf, firewall.tf, ec2.tf)
│   │   └── rules/                  Suricata rules for Network Firewall
│   ├── pipeline/                   CodePipeline + CodeBuild CI/CD
│   └── global/                     State backend (S3 + DynamoDB)
│
├── python/                         Network automation & validation
│   ├── netops/
│   │   ├── configurator/           Router config automation (Netmiko + Jinja2)
│   │   │   ├── push_config.py      Engine: render template → push via telnet
│   │   │   ├── inventory.yaml      All 20 GNS3 routers with ports and variables
│   │   │   └── templates/          Jinja2 templates (mpls_base, pe_vrf, ce_router)
│   │   ├── validators/             AWS drift detection (VPC routes, TGW state)
│   │   ├── collectors/             Gather state from AWS APIs (assume-role)
│   │   ├── reporters/              Output formatting
│   │   └── remediators/            Auto-fix (future)
│   └── tests/                      pytest test suite
│
├── operations/                     Operational tooling
│   ├── runbooks/                   Incident response procedures
│   ├── dashboards/                 CloudWatch definitions
│   └── alerting/                   EventBridge rules, Lambda monitors
│
├── docs/                           Documentation
│   ├── architecture/               Diagrams (centralized egress, MPLS topology)
│   ├── study-notes/                MPLS/BGP book notes + lab workbooks
│   └── phases/                     Implementation phase plans
│
└── .github/                        CI/CD workflows
    └── workflows/                  GitHub Actions (deploy-routers.yml)
```

---

## AWS Infrastructure (Deployed)

| Component | Account | Details |
|-----------|---------|---------|
| Transit Gateway | Networking | 4 route tables (fullmesh, shared, firewall, isolated) |
| Inspection VPC | Networking | Network Firewall + NAT GW + centralized egress |
| Network Firewall | Networking | Domain allow-list, Suricata IPS rules, stateless filtering |
| Spoke VPCs | Spoke accounts | IPAM-allocated /22, TGW-attached, default route to inspection |
| Shared VPC | Networking | Future shared services (DNS, endpoints) |
| EVE-NG VPC | Lab account | c5.metal for advanced labs (SR, EVPN, SD-WAN) |
| CI/CD Pipeline | Management | CodePipeline → CodeBuild → Terraform plan/apply |

---

## MPLS Lab (GNS3 Local)

20-router service provider topology running locally:

| Role | Routers | Protocols |
|------|---------|-----------|
| PE | R2, R8, R17, R18 | MP-BGP vpnv4, MPLS TE, VRF |
| P | R3, R4, R5, R6, R7, R13, R14, R15, R16 | OSPF area 0, LDP, RSVP-TE |
| CE | R1, R9, R10 (Customer A), R12 (B), R11 (C), R19 (D), R20 (E) | eBGP |

Labs cover: MPLS forwarding, L3VPN, Traffic Engineering, BGP design, Python automation.

---

## Usage

### Terraform (AWS Infrastructure)
```bash
cd terraform/environments/dev
terraform init && terraform plan
```

### Python — Router Automation (GNS3)
```bash
cd python
source .venv/bin/activate

# Configure a single router
python -m netops.configurator.push_config --router R13 --template mpls_base.j2

# Configure all P routers at once
python -m netops.configurator.push_config --role P --template mpls_base.j2

# Configure all PE routers with VRF template
python -m netops.configurator.push_config --role PE --template pe_vrf.j2

# Configure all CE routers
python -m netops.configurator.push_config --role CE --template ce_router.j2

# Dry run (preview without pushing)
python -m netops.configurator.push_config --all --template mpls_base.j2 --dry-run
```

### Python — AWS Validation
```bash
cd python
source .venv/bin/activate

# Validate VPC routes in a spoke account
python -m netops.validators.vpc_routes_validator --account-id <SPOKE_ACCOUNT> --region eu-west-1
```

---

## Implementation Phases

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Network foundation (TGW, VPCs, multi-account) | ✅ Complete |
| 2 | Segmentation & Inspection (Network Firewall, centralized egress) | ✅ Complete |
| 3 | Shared Services (Route 53, VPC Endpoints) | 🔲 Planned |
| 4 | Observability (Flow Logs, CloudWatch, Alarms) | 🔲 Planned |
| 5 | Hybrid Connectivity (AWS VPN + On-Prem) | 🔲 Planned |
| 6 | Python AWS Validation (drift detection, route validators) | 🟡 In Progress |
| 7 | Python Network Automation (Netmiko + Jinja2 for GNS3 lab) | 🟡 In Progress |
| 8 | MPLS Lab (L3VPN, Traffic Engineering, BGP Design) | 🟡 In Progress |
| 9 | Multi-Region | 🔲 Planned |
| 10 | Production Hardening | 🔲 Planned |

---

## Author

**Renato Gentil** — Sr. Technical Account Manager, AWS
- 15 years enterprise and cloud networking
- AWS Solutions Architect Professional, Advanced Networking Specialty, DevOps Professional
- Specialist in BGP, MPLS, hybrid connectivity, and network automation
