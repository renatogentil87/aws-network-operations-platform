# EVE-NG Lab Topology — Complete Reference (3 ISPs)

**Platform:** GNS3 on EC2 — IOS-XRv 9000 + Arista vEOS CEs
**NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3 (NIC0/NIC1=internal/mgmt)

---

## Three Autonomous Systems

| AS | Name | IGP | Transport | Nodes |
|----|------|-----|-----------|-------|
| **65100** | **Emerald** | IS-IS L2 | LDP | PCE1, P2, P1, ASBR1, PE1, PE2 |
| **65300** | **Gold** (transit) | IS-IS L2 | SRv6 | ASBR3(RR/PCE), ASBR4, P6, PE5, PE6 |
| **65200** | **Garnet** | IS-IS L2 | SR-MPLS | PCE, P3, P4, P5, ASBR2, PE3, PE4 |

---

## Node Inventory (20 XRv + 9 CEs = 29 nodes)

### Emerald — AS 65100 (IS-IS + LDP)

| Node | Role | Loopback |
|------|------|----------|
| PE1 | PE | 1.1.1.1 |
| PE2 | PE | 2.2.2.2 |
| P1 | P | 3.3.3.3 |
| P2 | P | 4.4.4.4 |
| ASBR1 | ASBR | 5.5.5.5 |
| PCE1 | RR + PCE | 6.6.6.6 |

### Gold — AS 65300 (IS-IS + SRv6) — Transit Provider

| Node | Role | Loopback |
|------|------|----------|
| ASBR3 | ASBR + RR + PCE | 21.21.21.21 |
| ASBR4 | ASBR | 22.22.22.22 |
| P6 | P | 23.23.23.23 |
| PE5 | PE | 24.24.24.24 |
| PE6 | PE | 25.25.25.25 |

### Garnet — AS 65200 (IS-IS + SR-MPLS)

| Node | Role | Loopback |
|------|------|----------|
| PE3 | PE | 11.11.11.11 |
| PE4 | PE | 12.12.12.12 |
| P3 | P | 13.13.13.13 |
| P4 | P | 14.14.14.14 |
| P5 | P | 15.15.15.15 |
| ASBR2 | ASBR | 16.16.16.16 |
| PCE | RR + PCE | 17.17.17.17 |

### CEs (Arista vEOS)

| Node | ASN | Protocol | Connected To | Customer |
|------|-----|----------|-------------|----------|
| CE1 | 65012 | eBGP | PE1 | Customer A |
| CE2 | 65012 | eBGP | PE1 + PE2 (dual-homed) | Customer A |
| CE3 | — | OSPF Area 0 | PE2 | (Emerald only) |
| CE4 | 65013 | eBGP | PE3 | Customer B |
| CE5 | — | EVPN VLAN100 | PE3 + PE4 (dual-homed) | Customer C |
| CE6 | — | OSPF Area 0 | PE4 | (Garnet only) |
| CE7 | — | EVPN VLAN100 | PE6 | Customer C |
| CE8 | 65012 | eBGP | PE5 + PE6 (dual-homed) | Customer A |
| CE9 | 65013 | eBGP | PE5 | Customer B |

---

## Full Link Map

### Emerald Core

| From | NIC → Gi | To | NIC → Gi | Subnet |
|------|----------|-----|----------|--------|
| PCE1 | NIC5 → Gi3 | P2 | NIC5 → Gi3 | 10.1.1.0/24 |
| P2 | NIC4 → Gi2 | ASBR1 | NIC4 → Gi2 | 10.1.2.0/24 |
| P2 | NIC3 → Gi1 | P1 | NIC3 → Gi1 | 10.1.3.0/24 |
| P1 | NIC4 → Gi2 | PE1 | NIC4 → Gi2 | 10.1.4.0/24 |
| P1 | NIC2 → Gi0 | PE2 | NIC2 → Gi0 | 10.1.5.0/24 |
| PE1 | NIC5 → Gi3 | PE2 | NIC5 → Gi3 | 10.1.6.0/24 |

### Gold Core

| From | NIC → Gi | To | NIC → Gi | Subnet |
|------|----------|-----|----------|--------|
| ASBR3 | NIC4 → Gi2 | ASBR4 | NIC4 → Gi2 | 10.3.1.0/24 |
| ASBR3 | NIC3 → Gi1 | P6 | NIC3 → Gi1 | 10.3.2.0/24 |
| ASBR4 | NIC2 → Gi0 | P6 | NIC2 → Gi0 | 10.3.3.0/24 |
| P6 | NIC4 → Gi2 | PE5 | NIC4 → Gi2 | 10.3.4.0/24 |
| P6 | NIC5 → Gi3 | PE6 | NIC5 → Gi3 | 10.3.5.0/24 |

### Garnet Core

| From | NIC → Gi | To | NIC → Gi | Subnet |
|------|----------|-----|----------|--------|
| PCE | NIC5 → Gi3 | P3 | NIC5 → Gi3 | 10.2.1.0/24 |
| ASBR2 | NIC4 → Gi2 | P3 | NIC4 → Gi2 | 10.2.2.0/24 |
| P3 | NIC2 → Gi0 | P4 | NIC2 → Gi0 | 10.2.3.0/24 |
| P3 | NIC3 → Gi1 | P5 | NIC3 → Gi1 | 10.2.4.0/24 |
| P4 | NIC5 → Gi3 | P5 | NIC5 → Gi3 | 10.2.5.0/24 |
| P4 | NIC3 → Gi1 | PE3 | NIC3 → Gi1 | 10.2.6.0/24 |
| P5 | NIC4 → Gi2 | PE4 | NIC4 → Gi2 | 10.2.7.0/24 |
| PE3 | NIC5 → Gi3 | PE4 | NIC5 → Gi3 | 10.2.8.0/24 |

### Inter-AS Links (3 links)

| From | NIC → Gi | To | NIC → Gi | Subnet | Path |
|------|----------|-----|----------|--------|------|
| ASBR1 | NIC3 → Gi1 | ASBR2 | NIC3 → Gi1 | 10.0.1.0/24 | Emerald↔Garnet DIRECT |
| ASBR1 | NIC5 → Gi3 | ASBR3 | NIC5 → Gi3 | 10.0.2.0/24 | Emerald↔Gold |
| ASBR4 | NIC5 → Gi3 | ASBR2 | NIC5 → Gi3 | 10.0.3.0/24 | Gold↔Garnet |

### PE-CE Links (Emerald)

| PE | NIC → Gi | CE | Subnet | Protocol |
|----|----------|-----|--------|----------|
| PE1 | NIC2 → Gi0 | CE1 e0 | 192.168.1.0/24 | eBGP 65012 |
| PE1 | NIC3 → Gi1 | CE2 e0 | 192.168.2.0/24 | eBGP 65012 |
| PE2 | NIC3 → Gi1 | CE2 e1 | 192.168.3.0/24 | eBGP 65012 (dual-homed) |
| PE2 | NIC4 → Gi2 | CE3 e0 | 192.168.4.0/24 | OSPF Area 0 |

### PE-CE Links (Gold)

| PE | NIC → Gi | CE | Subnet | Protocol |
|----|----------|-----|--------|----------|
| PE5 | NIC2 → Gi0 | CE9 e0 | 192.168.11.0/24 | eBGP 65013 |
| PE5 | NIC3 → Gi1 | CE8 e0 | 192.168.12.0/24 | eBGP 65012 |
| PE6 | NIC3 → Gi1 | CE8 e1 | 192.168.13.0/24 | eBGP 65012 (dual-homed) |
| PE6 | NIC2 → Gi0 | CE7 e0 | 192.168.14.0/24 | EVPN VLAN100 |

### PE-CE Links (Garnet)

| PE | NIC → Gi | CE | Subnet | Protocol |
|----|----------|-----|--------|----------|
| PE3 | NIC4 → Gi2 | CE4 e0 | 172.16.1.0/24 | eBGP 65013 |
| PE3 | NIC2 → Gi0 | CE5 e0 | 172.16.2.0/24 | EVPN VLAN100 |
| PE4 | NIC3 → Gi1 | CE5 e1 | 172.16.3.0/24 | EVPN VLAN100 (dual-homed) |
| PE4 | NIC2 → Gi0 | CE6 e0 | 172.16.4.0/24 | OSPF Area 0 |

---

## Customer Design (spans multiple SPs)

| Customer | ASN | CEs | SPs | Protocol | Inter-AS needed? |
|----------|-----|-----|-----|----------|-----------------|
| **Customer A** | 65012 | CE1+CE2 (Emerald) + CE8 (Gold) | Emerald + Gold | eBGP | YES (Emerald↔Gold) |
| **Customer B** | 65013 | CE9 (Gold) + CE4 (Garnet) | Gold + Garnet | eBGP | YES (Gold↔Garnet) |
| **Customer C** | — | CE5 (Garnet) + CE7 (Gold) | Garnet + Gold | EVPN VLAN100 | YES (EVPN inter-AS) |
| CE3 | — | CE3 (Emerald only) | Emerald | OSPF | No |
| CE6 | — | CE6 (Garnet only) | Garnet | OSPF | No |

---

## Addressing Summary

| Range | Purpose |
|-------|---------|
| 1.1.1.1 – 6.6.6.6 | Emerald loopbacks |
| 11.11.11.11 – 17.17.17.17 | Garnet loopbacks |
| 21.21.21.21 – 25.25.25.25 | Gold loopbacks |
| 10.1.x.0/24 | Emerald core links |
| 10.2.x.0/24 | Garnet core links |
| 10.3.x.0/24 | Gold core links |
| 10.0.1.0/24 | Inter-AS: Emerald↔Garnet direct |
| 10.0.2.0/24 | Inter-AS: Emerald↔Gold |
| 10.0.3.0/24 | Inter-AS: Gold↔Garnet |
| 192.168.1-4.0/24 | Emerald PE-CE |
| 192.168.11-14.0/24 | Gold PE-CE |
| 172.16.1-4.0/24 | Garnet PE-CE |

---

## Key Design Scenarios This Topology Enables

- **Multi-hop inter-AS VPN** — Customer A traffic: CE1(Emerald) → ASBR1 → ASBR3 → Gold core → PE5 → CE8. Two AS boundaries crossed.
- **Transit provider** — Gold provides transit between Emerald and Garnet. Traffic can go direct (ASBR1↔ASBR2) or via Gold (ASBR1↔ASBR3↔ASBR4↔ASBR2). BGP path selection decides.
- **Three different transport technologies** — LDP (Emerald), SR-MPLS (Garnet), SRv6 (Gold). Migration and interworking scenarios.
- **EVPN across SPs** — Customer C: CE5 (Garnet EVPN) ↔ CE7 (Gold EVPN). EVPN inter-AS.
- **Same customer on 3 transport technologies** — Customer A uses LDP (Emerald), SRv6 (Gold). Customer B uses SRv6 (Gold), SR-MPLS (Garnet).
- **Dual-homed CEs** — CE2 (PE1+PE2 in Emerald), CE8 (PE5+PE6 in Gold), CE5 (PE3+PE4 in Garnet).
- **BGP path diversity** — 3 inter-AS links gives multiple paths between any two SPs. Community-based traffic engineering.
