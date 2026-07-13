# Study Plan — Principal Cloud Network Architect

**Start Date:** 2026-07-13
**Pace:** 6-10 hours/week
**Philosophy:** Learn → Practice → Automate → Document → Publish → Move On

---

## Books (in order)

| # | Book | Why | Target |
|---|------|-----|--------|
| 1 | MPLS Fundamentals (Luc De Ghein) | Foundation for MPLS/VPN, label switching, LDP, TE | Jul–Aug 2026 |
| 2 | BGP Design and Implementation (Randy Zhang) | Advanced BGP — design patterns, communities, scaling, traffic engineering | Aug–Sep 2026 |
| 3 | MPLS in the SDN Era (Antonio Sanchez-Monge) | Modern MPLS + Segment Routing, bridges traditional to SDN | Sep–Oct 2026 |
| 4 | Building Data Centers with VXLAN BGP EVPN (Lukas Krattiger) | Data center fabric — spine/leaf, overlay, multi-tenancy | Oct–Nov 2026 |
| 5 | Cisco ENCOR Official Cert Guide (350-401) | Enterprise architecture — SDA, QoS, security, automation | Ongoing reference |
| 6 | Cisco ENAUTO Official Cert Guide (300-435) | Network automation — YANG, RESTCONF, NETCONF, Python, Ansible | Nov–Dec 2026 |
| 7 | SD-WAN Architecture and Design (Jason Gooley) | SD-WAN architecture, policy, segmentation, cloud integration | Dec 2026 |

---

## Labs (mapped to books)

### MPLS Labs (Book 1 & 3)

| Lab | Concepts |
|-----|----------|
| MPLS forwarding basics | Label switching, LDP, PHP, traceroute with labels |
| MPLS L3VPN (VPNv4) | VRF, RD, RT, PE-CE routing (BGP & OSPF), MP-BGP |
| MPLS Traffic Engineering | RSVP-TE, explicit paths, FRR, bandwidth reservation |
| Inter-AS MPLS VPN | Option A/B/C, multi-provider connectivity |
| Segment Routing | SR-MPLS, SRGB, adjacency SIDs, TI-LFA |

### BGP Labs (Book 2)

| Lab | Concepts |
|-----|----------|
| eBGP multi-homing | Dual ISP, AS-PATH manipulation, default routes |
| iBGP full mesh + Route Reflectors | iBGP scaling, RR design, cluster-id |
| BGP communities for traffic engineering | Standard/extended communities, local-pref, MED |
| BGP prefix filtering | Prefix lists, route maps, AS-PATH ACLs, bogon filtering |
| BGP failover with BFD | Sub-second convergence, BFD timers, graceful restart |
| BGP to real AWS (VPN + TGW) | eBGP over IPSec, route propagation, AS-PATH prepend |

### EVPN/VXLAN Labs (Book 4)
**Requires:** Arista vEOS (free from arista.com)

| Lab | Concepts |
|-----|----------|
| VXLAN fabric (2 spine, 4 leaf) | Underlay eBGP, VXLAN encapsulation, VTEPs |
| EVPN Type-2 (MAC/IP advertisement) | Host learning, ARP suppression, BUM handling |
| EVPN Type-5 (IP prefix routing) | Inter-VXLAN routing, symmetric/asymmetric IRB |
| Multi-tenancy with EVPN | VRFs over VXLAN, RT import/export, tenant isolation |
| DCI with EVPN | Data center interconnect, stretch fabric patterns |

### Network Automation Labs (Book 6)

| Lab | Concepts |
|-----|----------|
| NETCONF + YANG | ncclient, get-config, edit-config, YANG models |
| RESTCONF (IOS-XE) | REST APIs, JSON/XML payloads, CRUD operations |
| Ansible network roles | ios_config, ios_command, roles, idempotency |
| Python + Nornir | Inventory, concurrent tasks, structured results |
| CI/CD for network config | Git push → validate → deploy → verify pipeline |
| Desired-state validation | YAML truth → collect actual → compare → report drift |

### SD-WAN Labs (Book 7)

| Lab | Concepts |
|-----|----------|
| SD-WAN architecture overview | Controller model, overlay/underlay, OMP |
| SD-WAN policy & segmentation | App-aware routing, VPN segmentation, SLA classes |
| SD-WAN + cloud integration | Cloud onramp, colocation, DX/VPN coexistence |

### AWS Hybrid Labs (ongoing — tied to this platform)

| Lab | Concepts |
|-----|----------|
| TGW multi-account with centralized inspection | Firewall VPC, appliance mode, split routing |
| Cloud WAN with advanced routing policies | Segments, sharing, summarization, local-pref |
| Direct Connect traffic engineering | DXGW, Transit VIF, BGP communities, failover |
| VPN failover with BGP | AS-PATH prepend, BFD, convergence timing |
| Hybrid DNS (Route 53 Resolver) | Conditional forwarding, on-prem zone resolution |
| Network observability | VPC Flow Logs, CloudWatch metrics, alerting |

---

## Certifications

| Cert | Target Date | Notes |
|------|-------------|-------|
| CCNP ENCOR (350-401) | Nov 2026 | Take after books 1-4 + labs |
| CCNP ENAUTO (300-435) | Dec 2026 | Take after book 6 + automation labs |

---

## Monthly Targets

| Month | Book Focus | Labs | Output |
|-------|-----------|------|--------|
| Jul | MPLS Fundamentals (Ch 1-11) | MPLS forwarding, L3VPN | Book chapters 9-10 |
| Aug | MPLS finish + BGP Design (Ch 1-12) | eBGP, iBGP, RR, communities | Book chapters 11-12 |
| Sep | BGP finish + MPLS SDN Era (Ch 1-12) | BGP filtering, failover, SR | Book chapters 13-14 |
| Oct | MPLS SDN finish + EVPN/VXLAN | VXLAN fabric, EVPN Type-2/5 | Book chapters 15-16 |
| Nov | ENCOR review + ENAUTO (Ch 1-15) | NETCONF, RESTCONF, Ansible | Book chapters 17-20 + ENCOR exam |
| Dec | ENAUTO finish + SD-WAN | CI/CD, desired-state, SD-WAN | Book chapters 21-24 + ENAUTO exam |

---

## EVE-NG Lab Environment

- **Instance:** c5.metal (Eveng AWS account)
- **Images:** Cisco vIOS Router, Cisco vIOS L2, FortiGate VM
- **Needed:** Arista vEOS (free — download from arista.com for EVPN/VXLAN labs)
- **Note:** Stop instance when not in use (~$4/hr). IOL images don't work on AWS kernel — use QEMU only.
