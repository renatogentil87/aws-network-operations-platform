# AWS Network Operations Platform

A hybrid network operations platform that covers cloud infrastructure (Terraform), network validation (Python), on-prem automation (Ansible), and operational tooling — all connected through a GNS3 lab that peers with real AWS infrastructure via VPN.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Hybrid Network Operations Platform                     │
├─────────────────┬──────────────────┬──────────────────┬─────────────────┤
│   Terraform     │     Python       │     Ansible      │   Operations    │
│   (Cloud Infra) │  (Validation)    │  (On-Prem Auto)  │  (Runbooks)     │
├─────────────────┼──────────────────┼──────────────────┼─────────────────┤
│ • TGW           │ • Route drift    │ • BGP config     │ • BGP flap      │
│ • VPC + Subnets │ • BGP health     │ • OSPF config    │   response      │
│ • IPAM          │ • VPN state      │ • VPN tunnels    │ • VPN tunnel    │
│ • NOTG tags     │ • Isolation audit│ • Route audit    │   down          │
│ • RAM shares    │ • Hybrid compare │ • Emergency      │ • Route leak    │
│ • Multi-account │ • HTML reports   │   shutdown       │   detection     │
└─────────────────┴──────────────────┴──────────────────┴─────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   Desired State    │
                    │  (Source of Truth) │
                    │  YAML definitions  │
                    └───────────────────┘
```

## Repository Structure

```
├── terraform/                      Cloud infrastructure (EXISTING — pipeline active)
│   ├── modules/                    TGW, VPC, IPAM modules
│   ├── environments/dev/           Dev environment composition
│   └── pipeline/                   CodePipeline + CodeBuild CI/CD
│
├── python/                         Network validation & operations
│   ├── netops/
│   │   ├── validators/             Route validation, drift detection, BGP health
│   │   ├── collectors/             Gather state from AWS + on-prem devices
│   │   ├── remediators/            Auto-fix (shutdown peer, failover, create ticket)
│   │   ├── reporters/              HTML reports, metrics export
│   │   └── cli.py                  CLI entry point: `netops validate|collect|report`
│   ├── tests/                      pytest test suite
│   └── pyproject.toml              Package definition
│
├── ansible/                        On-prem network automation
│   ├── inventory/                  GNS3 lab + production inventories
│   ├── playbooks/                  BGP config, OSPF config, route audit, emergency shutdown
│   ├── roles/                      Reusable roles (base_router, bgp_peer, vpn_to_aws)
│   └── ansible.cfg
│
├── labs/                           GNS3 lab environment
│   ├── topology/                   Lab topology (4 routers: core, edge1, edge2, branch)
│   ├── configs/                    Initial router configurations
│   └── exercises/                  Progressive hands-on scenarios
│
├── operations/                     Operational tooling
│   ├── runbooks/                   Incident response procedures
│   ├── dashboards/                 CloudWatch + Grafana definitions
│   └── alerting/                   EventBridge rules, Lambda monitors
│
├── desired-state/                  Source of truth (YAML)
│   ├── desired-routes-tgw.yaml     Expected TGW route table state
│   ├── desired-bgp-peers.yaml      Expected BGP sessions (cloud + on-prem)
│   └── desired-vpn-tunnels.yaml    Expected VPN tunnel states
│
├── docs/                           Architecture docs & phase plans
└── configs/                        Shared configuration
```

## Quick Start

### Cloud Infrastructure (Terraform)
```bash
cd terraform/environments/dev
terraform init
terraform plan    # Pipeline runs this automatically on push
```

### Network Validation (Python)
```bash
cd python
pip install -e .
netops validate routes --region eu-west-1
netops validate bgp --region eu-west-1 --device router-edge1
netops collect hybrid --region eu-west-1 --device router-edge1
netops report health --format html
```

### On-Prem Automation (Ansible)
```bash
cd ansible
ansible-playbook playbooks/bgp_config.yml -i inventory/gns3_lab.yml
ansible-playbook playbooks/route_audit.yml -i inventory/gns3_lab.yml
```

### GNS3 Lab
See `labs/topology/README.md` for topology setup and `labs/exercises/` for progressive scenarios.

## Learning Path

| Phase | Focus | Skills |
|-------|-------|--------|
| 1 | Cloud Automation | Terraform modules, multi-account, CI/CD pipeline |
| 2 | Network Validation | Python + boto3, desired-state comparison, pytest |
| 3 | On-Prem Automation | Ansible, netmiko, NAPALM, GNS3 lab |
| 4 | Hybrid Operations | End-to-end validation (both sides), closed-loop remediation |
| 5 | Production Operations | Monitoring, alerting, runbooks, self-healing |

## How It All Connects

1. **Terraform** deploys TGW, VPCs, VPN in AWS
2. **Ansible** configures BGP/OSPF on the on-prem routers (GNS3 lab → production)
3. **VPN tunnel** connects the GNS3 lab to real AWS TGW
4. **Python validators** check BOTH sides agree on routes, BGP state, tunnel health
5. **Operations tooling** alerts when drift is detected and auto-remediates if threshold is crossed

## Key Design Principles

- **Desired state as YAML** — Define what the network SHOULD look like, validate continuously
- **Validate before and after** — Every change runs validators pre/post
- **Closed-loop operations** — Detect → Alert → Validate → Remediate → Verify
- **Cloud and on-prem are one system** — Not two separate tools, one platform that sees both

## License

MIT
