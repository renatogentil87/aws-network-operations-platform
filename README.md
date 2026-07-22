# AWS Network Operations Platform

A production-grade hybrid network operations platform implementing closed-loop automation for enterprise AWS environments. Built to operate cloud and on-premises networks as a single system through desired-state validation, automated remediation, and continuous compliance.

---

## What This Is

This platform manages the full lifecycle of hybrid network operations across a multi-account AWS environment connected to on-premises infrastructure via Site-to-Site VPN. It combines infrastructure-as-code (Terraform), network validation (Python), and operational tooling into a unified system that detects drift, validates state, and remediates issues automatically.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Hybrid Network Operations Platform                     │
├─────────────────┬──────────────────┬──────────────────┬─────────────────┤
│   Terraform     │     Python       │     Ansible      │   Operations    │
│  (Cloud Infra)  │  (Validation)    │  (On-Prem Auto)  │  (Runbooks)     │
├─────────────────┼──────────────────┼──────────────────┼─────────────────┤
│ • TGW           │ • Route drift    │ • BGP config     │ • BGP flap      │
│ • VPC + Subnets │ • BGP health     │ • OSPF config    │   response      │
│ • IPAM          │ • VPN state      │ • VPN tunnels    │ • VPN tunnel    │
│ • Multi-account │ • Isolation audit│ • Route audit    │   down          │
│ • EC2 (lab)     │ • Hybrid compare │ • Emergency      │ • Route leak    │
│ • RAM shares    │ • HTML reports   │   shutdown       │   detection     │
└─────────────────┴──────────────────┴──────────────────┴─────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   Desired State    │
                    │  (Source of Truth) │
                    │  YAML definitions  │
                    └───────────────────┘
```

---

## Repository Structure

```
├── terraform/                      Cloud infrastructure (CI/CD pipeline active)
│   ├── modules/                    Reusable modules (VPC, TGW, EC2, VPN, Route53, etc.)
│   ├── environments/dev/           Environment composition layer
│   ├── pipeline/                   CodePipeline + CodeBuild CI/CD
│   └── global/                     State backend (S3 + DynamoDB)
│
├── python/                         Network validation & operations CLI
│   ├── netops/
│   │   ├── validators/             Route validation, drift detection, BGP health
│   │   ├── collectors/             Gather state from AWS + on-prem devices
│   │   ├── remediators/            Auto-fix (shutdown peer, failover, create ticket)
│   │   ├── reporters/              HTML reports, metrics export
│   │   └── cli.py                  CLI entry point: netops validate|collect|report
│   └── tests/                      pytest test suite
│
├── ansible/                        On-prem network automation
│   ├── inventory/                  Device inventories (lab + production)
│   ├── playbooks/                  BGP config, OSPF config, route audit, emergency shutdown
│   └── roles/                      Reusable roles (base_router, bgp_peer, vpn_to_aws)
│
├── operations/                     Operational tooling
│   ├── runbooks/                   Incident response procedures
│   ├── dashboards/                 CloudWatch + Grafana definitions
│   └── alerting/                   EventBridge rules, Lambda monitors
│
├── desired-state/                  Source of truth (YAML)
│   ├── desired-routes-tgw.yaml     Expected TGW route table state
│   └── desired-bgp-peers.yaml     Expected BGP sessions
│
├── docs/                           Architecture documentation
│   ├── phases/                     Implementation phase plans (0-13)
│   ├── architecture/               Architecture decision records
│   └── cross-account-deployment.md Cross-account Terraform patterns
│
└── .github/                        CI/CD workflows
```

---

## Key Design Principles

- **Desired state as YAML** — Define what the network SHOULD look like, validate continuously
- **Validate before and after** — Every change runs validators pre/post
- **Closed-loop operations** — Detect → Alert → Validate → Remediate → Verify
- **Cloud and on-prem are one system** — One platform that sees both sides
- **Multi-account by default** — Cross-account roles, RAM sharing, centralized TGW

---

## Infrastructure

| Component | Account | Details |
|-----------|---------|---------|
| Transit Gateway | Network (hub) | Central routing, multi-account RAM share, auto-accept |
| Inspection VPC | Network | Centralized firewall path (future Network Firewall) |
| Workload VPCs | Spoke accounts | IPAM-allocated /22, TGW-attached, segmented routing |
| CI/CD Pipeline | Management | CodePipeline → CodeBuild → Terraform plan/apply |
| State Backend | Management | S3 + DynamoDB locking |

---

## Usage

### Terraform (Infrastructure)
```bash
cd terraform/environments/dev
terraform init && terraform plan
```

### Python (Validation)
```bash
cd python && pip install -e .
netops validate routes --region eu-west-1
netops validate bgp --device router-edge1
netops report health --format html
```
---

## Implementation Phases

| Phase | Focus | Status |
|-------|-------|--------|
| 0 | Repository foundation + CI/CD | Complete |
| 1 | Network foundation (TGW, VPCs, multi-account) | Complete |
| 2 | Multi-region resilience | 🔲 Planned |
| 3 | Observability platform | 🔲 Planned |
| 4 | Python CLI framework | 🔲 Planned |
| 5 | Inventory engine | 🔲 Planned |
| 6 | Validation framework | 🔲 Planned |
| 7 | Automated network testing | 🔲 Planned |
| 8 | Drift detection | 🔲 Planned |
| 9 | Automated recovery | 🔲 Planned |
| 10 | Chaos engineering | 🔲 Planned |
| 11 | Operational runbooks | 🔲 Planned |
| 12 | Reporting | 🔲 Planned |
| 13 | Operational maturity scoring | 🔲 Planned |

---

## Author

**Renato Gentil** — Sr. Technical Account Manager, AWS
- 15 years enterprise and cloud networking
- AWS Solutions Architect Professional, Advanced Networking Specialty, DevOps Professional
- Specialist in BGP, MPLS, hybrid connectivity, and network automation
