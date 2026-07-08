# GNS3 Lab — Hybrid Network Topology

## Overview

A minimal lab (4-5 routers) designed to practice automation with Python (netmiko/napalm) and Ansible against real routing protocols, then connect to AWS via VPN for end-to-end hybrid validation.

## Topology

```
                        [AWS TGW]
                            |
                       IPSec VPN (BGP)
                            |
                    ┌───────────────┐
                    │  Router-Edge1  │  AS 65000 (eBGP to AWS, iBGP to Core)
                    │  10.0.0.1/30  │
                    └───────┬───────┘
                            │ OSPF Area 0
                            │
                    ┌───────┴───────┐
                    │  Router-Core   │  AS 65000 (Route Reflector, OSPF ABR)
                    │  10.0.0.5/30  │
                    └──┬─────────┬──┘
                       │         │
              OSPF Area 1    OSPF Area 2
                       │         │
              ┌────────┴──┐  ┌───┴────────┐
              │Router-Edge2│  │Router-Branch│
              │ 10.0.1.1  │  │ 10.0.2.1   │
              └───────────┘  └────────────┘
                    │
               IPSec VPN (backup to AWS — optional)
```

## Devices

| Device | Role | Interfaces | Protocols |
|--------|------|-----------|-----------|
| Router-Core | Route Reflector, OSPF ABR | Gi0/0, Gi0/1, Gi0/2, Lo0 | OSPF (multi-area), iBGP RR |
| Router-Edge1 | AWS VPN termination (primary) | Gi0/0, Gi0/1, Tunnel0/1 | eBGP to AWS, iBGP to Core, OSPF Area 0 |
| Router-Edge2 | Redundant edge / backup path | Gi0/0, Gi0/1 | iBGP to Core, OSPF Area 1 |
| Router-Branch | Remote site simulation | Gi0/0, Lo0 | OSPF Area 2 |

## IP Addressing

| Network | CIDR | Purpose |
|---------|------|---------|
| 10.0.0.0/30 | Core ↔ Edge1 | OSPF Area 0 backbone |
| 10.0.0.4/30 | Core ↔ Edge2 | OSPF Area 1 link |
| 10.0.0.8/30 | Core ↔ Branch | OSPF Area 2 link |
| 10.0.1.0/24 | Edge2 LAN | Simulated workload network |
| 10.0.2.0/24 | Branch LAN | Simulated branch network |
| 10.255.0.x/32 | Loopbacks | Router IDs & iBGP peering |
| 169.254.x.x/30 | VPN tunnels | AWS VPN inside addresses |

## BGP Design

| Session | Type | From | To | Purpose |
|---------|------|------|-----|---------|
| Edge1 → AWS TGW | eBGP | AS 65000 | AS 64512 | Advertise on-prem routes to AWS |
| Edge1 → Core | iBGP | AS 65000 | AS 65000 | Distribute AWS routes internally |
| Core → Edge2 | iBGP (RR) | AS 65000 | AS 65000 | Route Reflector to all internal peers |

## Lab Exercises

See `labs/exercises/` for progressive hands-on scenarios.

## Connecting to Real AWS

1. Create a Site-to-Site VPN in your AWS account (Terraform handles this)
2. Download the VPN config for Cisco IOS
3. Apply to Router-Edge1 (Tunnel0 + Tunnel1)
4. BGP session comes up → on-prem routes propagate to TGW → AWS routes propagate to on-prem
5. Run `netops validate bgp` from the Python CLI to confirm both sides agree

## Requirements

- GNS3 2.2+ (or Containerlab as alternative)
- Cisco IOSv or CSR1000v images (IOSv L3 is sufficient)
- 8GB RAM minimum (4 routers × ~512MB each)
