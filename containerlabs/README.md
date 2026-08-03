# Containerlab — MPLS-TE Lab Environment

## Architecture (40 Nodes)

```
                         ┌─────────────────────────────────────┐
                         │         CORE BACKBONE (L2)           │
                         │                                     │
                         │   core-p1 ═══ core-p2               │
                         │     ║  ╲      ╱  ║                  │
                         │     ║   ╲    ╱   ║                  │
                         │   core-p3 ═══ core-p4               │
                         │                                     │
                         │   core-rr1        core-rr2          │
                         │   (cluster 0.0.0.1)                 │
                         └────────┬──────────┬─────────────────┘
                                  │          │
              ┌───────────────────┼──────────┼───────────────────┐
              │                   │          │                   │
    ┌─────────▼────────┐  ┌──────▼──────────▼──┐  ┌────────────▼────────┐
    │   REGION WEST    │  │   REGION CENTRAL    │  │    REGION EAST      │
    │                  │  │                     │  │                     │
    │ west-p1─p2─p3   │  │ central-p1─p2─p3   │  │  east-p1─p2─p3     │
    │  reg-rr-west1   │  │                     │  │  reg-rr-east1      │
    │                  │  │                     │  │                     │
    │ PE1  PE2  PE3   │  │  PE1  PE2  PE3     │  │  PE1  PE2  PE3     │
    │  │    │    │    │  │   │    │    │      │  │   │    │    │      │
    │ CE1  CE2  CE6   │  │  CE3  CE4  CE7    │  │  CE5  CE8  CE9    │
    │      CE10       │  │                    │  │                    │
    └─────────────────┘  └────────────────────┘  └────────────────────┘

    Customer-A (VRF-A): CE1, CE2, CE3, CE4, CE5
    Customer-B (VRF-B): CE6, CE7, CE8, CE9, CE10
```

## Node Count

| Role | Count | Image | RAM/Node |
|------|-------|-------|----------|
| Core P | 4 | vJunos 26.2R1.7 | 4GB |
| Core RR | 2 | vJunos 26.2R1.7 | 4GB |
| Regional RR | 2 | vJunos 26.2R1.7 | 4GB |
| Regional P | 9 | vJunos 26.2R1.7 | 4GB |
| PE | 9 | vJunos 26.2R1.7 | 4GB |
| CE | 10 | FRRouting | 50MB |
| Mgmt | 4 | Alpine Linux | 50MB |
| **Total** | **40** | | **~108GB** |

## EC2 Instance

- **Type:** r5.4xlarge (128GB RAM, 16 vCPU) — $1.01/hr
- **OS:** Ubuntu 22.04
- **Storage:** 100GB gp3 (DeleteOnTermination=false)
- **Elastic IP:** Assigned for permanent access

## Route Reflector Design

### Hierarchical RR (2-Level)

| Level | Nodes | Cluster-ID | Clients |
|-------|-------|-----------|---------|
| Core (L2) | core-rr1, core-rr2 | 0.0.0.1 | Regional RRs (L1) |
| West (L1) | reg-rr-west1 | 10.0.1.1 | west-pe1, west-pe2, west-pe3 |
| East (L1) | reg-rr-east1 | 10.0.3.1 | east-pe1, east-pe2, east-pe3 |
| Central | (clients of core RR directly) | — | central-pe1, central-pe2, central-pe3 |

## Labs You Can Build

1. **MPLS-TE** — RSVP-TE LSPs between PEs, explicit paths, CSPF, FRR bypass
2. **L3VPN** — VRF-A and VRF-B, MP-BGP VPNv4, inter-region VPN connectivity
3. **Route Reflectors** — Hierarchical RR with cluster-IDs, additional-paths
4. **ECMP** — Equal-cost paths through core, load balancing verification
5. **Traffic Engineering** — Bandwidth reservation, auto-bandwidth, MBB
6. **Convergence Testing** — Link failures, bypass activation, reconvergence timing
7. **BGP Communities** — RT import/export, community-based filtering

## Quick Commands

```bash
# Deploy lab
clab deploy -t mpls-te-40-node.yaml

# Destroy lab
clab destroy -t mpls-te-40-node.yaml

# SSH into a node
ssh admin@clab-mpls-te-lab-west-pe1

# List all nodes
clab inspect -t mpls-te-40-node.yaml

# Save all configs
clab save -t mpls-te-40-node.yaml
```

## Setup (First Time)

```bash
# 1. Install containerlab
bash -c "$(curl -sL https://get.containerlab.dev)"

# 2. Install Docker
curl -fsSL https://get.docker.com | sh

# 3. Clone vrnetlab and build vJunos image
git clone https://github.com/vrnetlab/vrnetlab
cp /path/to/vJunos-router-26.2R1.7.qcow2 vrnetlab/vr-vjunos/
cd vrnetlab/vr-vjunos && make

# 4. Pull FRRouting
docker pull ghcr.io/frrouting/frr:latest

# 5. Deploy
cd /path/to/containerlabs
clab deploy -t mpls-te-40-node.yaml
```
