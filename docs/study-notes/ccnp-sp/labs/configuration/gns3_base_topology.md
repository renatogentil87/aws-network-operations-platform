# GNS3 Base Topology — Authoritative Reference

**Platform:** Cisco 7200, IOS 15.2 — local GNS3 on Mac
**Project:** BaseTopology
**Total:** 24 routers, 40 links, 2 autonomous systems

---

## AS X — AS 64512 (11 routers)

| Router | Role | Notes |
|--------|------|-------|
| R1 | PE | |
| R2 | PE | |
| X-PE3 | PE | |
| X-P1 | P | |
| X-P2 | P | |
| X-P3 | P | |
| X-ASBR1 | ASBR | Inter-AS eBGP to Y-ASBR1 |
| X-ASBR2 | ASBR | Inter-AS eBGP to Y-ASBR2 |
| X-CE1 | CE | Dual-homed (X-PE1 + X-PE2), backdoor link to X-CE2 |
| X-CE2 | CE | Dual-homed (X-PE2 + X-PE3), backdoor link to X-CE1 |
| X-CE3 | CE | Single-homed (X-PE3) |

## AS Y — AS 64513 (13 routers)

| Router | Role | Notes |
|--------|------|-------|
| Y-PE1 | PE | |
| Y-PE2 | PE | |
| R15 | P + **RR** | Route Reflector for AS Y |
| R17 | P + **RR** | Route Reflector for AS Y |
| Y-P3 | P | |
| Y-P4 | P | |
| Y-P5 | P | |
| Y-ASBR1 | ASBR | Inter-AS eBGP to X-ASBR1 |
| Y-ASBR2 | ASBR | Inter-AS eBGP to X-ASBR2 |
| Y-CE1 | CE | Single-homed (Y-PE1) |
| Y-CE2 | CE | Dual-homed (Y-PE1 + Y-PE2) |
| Y-CE3 | CE | Dual-homed (Y-PE1 + Y-PE2) |
| Y-CE4 | CE | Single-homed (Y-PE2), runs **OSPF** as PE-CE |

---

## Addressing Convention

| Scope | Range | Format |
|-------|-------|--------|
| **Loopbacks** | n.n.n.n/32 | See loopback table below |
| **Core links** (P-P, PE-P, ASBR-P, ASBR-ASBR, inter-AS) | 10.x.y.0/24 | Each end uses its own ID as host octet |
| **X-side PE-CE** | 192.168.x.y.0/24 | |
| **Y-side PE-CE** | 172.16.x.y.0/24 | |

### Loopback Assignments

| Router | Loopback0 | Router | Loopback0 |
|--------|-----------|--------|-----------|
| X-PE1 | 1.1.1.1/32 | Y-PE1 | 13.13.13.13/32 |
| X-PE2 | 2.2.2.2/32 | Y-PE2 | 14.14.14.14/32 |
| X-PE3 | 3.3.3.3/32 | Y-P1 | 15.15.15.15/32 |
| X-P1 | 4.4.4.4/32 | Y-P2 | 16.16.16.16/32 |
| X-P2 | 5.5.5.5/32 | Y-P3 | 17.17.17.17/32 |
| X-P3 | 6.6.6.6/32 | Y-P4 | 18.18.18.18/32 |
| X-ASBR1 | 7.7.7.7/32 | Y-P5 | 19.19.19.19/32 |
| X-ASBR2 | 8.8.8.8/32 | Y-ASBR1 | 20.20.20.20/32 |
| X-CE1 | 9.9.9.9/32 | Y-ASBR2 | 21.21.21.21/32 |
| X-CE2 | 10.10.10.10/32 | Y-CE1 | 22.22.22.22/32 |
| X-CE3 | 11.11.11.11/32 | Y-CE2 | 23.23.23.23/32 |
| | | Y-CE3 | 24.24.24.24/32 |
| | | Y-CE4 | 25.25.25.25/32 |

---

## Full Link Map (40 links)

### AS X — Internal Core (14 links)

| From | Interface | To | Interface | Subnet |
|------|-----------|-----|-----------|--------|
| X-PE1 | f0/0 | X-CE1 | f0/0 | 192.168.1.0/24 |
| X-PE1 | f1/0 | X-P2 | f0/0 | 10.1.5.0/24 |
| X-PE1 | f2/0 | X-P1 | f4/0 | 10.1.4.0/24 |
| X-PE2 | f0/0 | X-CE2 | f0/0 | 192.168.2.0/24 |
| X-PE2 | f1/0 | X-CE1 | f1/0 | 192.168.3.0/24 |
| X-PE2 | f2/0 | X-P1 | f2/0 | 10.2.4.0/24 |
| X-PE2 | f3/0 | X-P3 | f4/0 | 10.2.6.0/24 |
| X-PE2 | f4/0 | X-P2 | f4/0 | 10.2.5.0/24 |
| X-PE3 | f0/0 | X-CE3 | f0/0 | 192.168.4.0/24 |
| X-PE3 | f1/0 | X-CE2 | f1/0 | 192.168.5.0/24 |
| X-PE3 | f2/0 | X-P3 | f1/0 | 10.3.6.0/24 |
| X-PE3 | f3/0 | X-P1 | f3/0 | 10.3.4.0/24 |
| X-P1 | f0/0 | X-P3 | f0/0 | 10.4.6.0/24 |
| X-P1 | f1/0 | X-P2 | f1/0 | 10.4.5.0/24 |
| X-P2 | f2/0 | X-ASBR1 | f2/0 | 10.5.7.0/24 |
| X-P2 | f3/0 | X-ASBR2 | f3/0 | 10.5.8.0/24 |
| X-P3 | f2/0 | X-ASBR2 | f1/0 | 10.6.8.0/24 |
| X-P3 | f3/0 | X-ASBR1 | f3/0 | 10.6.7.0/24 |
| X-ASBR1 | f1/0 | X-ASBR2 | f2/0 | 10.7.8.0/24 |
| X-CE1 | f2/0 | X-CE2 | f2/0 | 192.168.100.0/24 |

### AS Y — Internal Core (14 links)

| From | Interface | To | Interface | Subnet |
|------|-----------|-----|-----------|--------|
| Y-PE1 | f0/0 | Y-P5 | f3/0 | 10.13.19.0/24 |
| Y-PE1 | f1/0 | Y-CE2 | f1/0 | 172.16.1.0/24 |
| Y-PE1 | f2/0 | Y-CE1 | f2/0 | 172.16.2.0/24 |
| Y-PE1 | f3/0 | Y-CE3 | f3/0 | 172.16.3.0/24 |
| Y-PE2 | f0/0 | Y-CE4 | f0/0 | 172.16.4.0/24 |
| Y-PE2 | f1/0 | Y-CE3 | f1/0 | 172.16.5.0/24 |
| Y-PE2 | f2/0 | Y-P4 | f2/0 | 10.14.18.0/24 |
| Y-PE2 | f3/0 | Y-CE2 | f2/0 | 172.16.6.0/24 |
| Y-P1 | f0/0 | Y-P3 | f1/0 | 10.15.17.0/24 |
| Y-P1 | f1/0 | Y-ASBR1 | f3/0 | 10.15.20.0/24 |
| Y-P1 | f2/0 | Y-ASBR2 | f2/0 | 10.15.21.0/24 |
| Y-P2 | f0/0 | Y-P3 | f0/0 | 10.16.17.0/24 |
| Y-P2 | f2/0 | Y-ASBR1 | f2/0 | 10.16.20.0/24 |
| Y-P2 | f3/0 | Y-ASBR2 | f3/0 | 10.16.21.0/24 |
| Y-P3 | f2/0 | Y-P5 | f0/0 | 10.17.19.0/24 |
| Y-P3 | f3/0 | Y-P4 | f0/0 | 10.17.18.0/24 |
| Y-P4 | f1/0 | Y-P5 | f1/0 | 10.18.19.0/24 |
| Y-ASBR1 | f1/0 | Y-ASBR2 | f1/0 | 10.20.21.0/24 |

### Inter-AS Links (2 links)

| From | Interface | To | Interface | Subnet |
|------|-----------|-----|-----------|--------|
| X-ASBR1 | f0/0 | Y-ASBR1 | f0/0 | 10.7.20.0/24 |
| X-ASBR2 | f0/0 | Y-ASBR2 | f0/0 | 10.8.21.0/24 |

---

## Topology Diagram

```
                         AS X (64512)                                    AS Y (64513)
                                                                        
 X-CE1 ─┬─ R1 ─── X-P2 ─┬─ X-ASBR1 ═══ Y-ASBR1 ─┬─ R16 ─── Y-P3 ─┬─ Y-P5 ─── Y-PE1 ─┬─ Y-CE1
 (dual) │              └─ X-P1 ─┤           ×              ├─ Y-P1(RR)     │      ├─ Y-P4 ─── Y-PE2 ─┤─ Y-CE4(OSPF)
  │     │                  │    │            │              │               │      │           │       │
  │     ├─ R2 ─── X-P2  ├─ X-ASBR2 ═══ Y-ASBR2 ─┘                └──────┘           ├─ Y-CE3
  │     │   │         └─ X-P3 ─┘     │                                                       └─ Y-CE2
  │     │   │              │          │
 X-CE2 ─┤   └─────────────┘          │
 (dual) │                             │
        └─ X-PE3 ─── X-P3            │
                └─── X-P1 ────────────┘
 X-CE3 ─── X-PE3

 Backdoor: X-CE1 ──── X-CE2 (same customer ASN)
```

---

## Design Features

- **Two full autonomous systems** — realistic inter-AS scenarios (Options A/B/C)
- **Redundant ASBRs** per side (X-ASBR1+2, Y-ASBR1+2) with cross-link
- **RRs in both ASes** — X-PE1/X-PE2 (on PEs), Y-P1/Y-P2 (on P routers) — two different RR placement models
- **Dual-homed CEs** — X-CE1 (X-PE1+X-PE2), X-CE2 (X-PE2+X-PE3), Y-CE2 (Y-PE1+Y-PE2), Y-CE3 (Y-PE1+Y-PE2)
- **Single-homed CEs** — X-CE3, Y-CE1, Y-CE4
- **Backdoor link** — X-CE1↔X-CE2 (same customer, OSPF sham-link scenarios)
- **OSPF PE-CE** — Y-CE4 runs OSPF with Y-PE2 (all others run eBGP)
- **Diverse core** — multiple paths through P routers for TE/FRR labs
- **Mirrors CCIE SP exam** — two SPs (like Emerald/Garnet), inter-AS, mixed PE-CE protocols

---

## Customer ASN Assignments (for PE-CE)

| Customer | CEs | ASN | PE-CE Protocol | Spans Both SPs? |
|----------|-----|-----|----------------|-----------------|
| Customer A | R9, R10 (X-side) + R23, R24 (Y-side) | 65001 | eBGP | **YES** (inter-AS VPN) |
| Customer B | R11 (X-side) + R25 (Y-side) | 65002 | eBGP | **YES** (inter-AS VPN) |
| Customer C | R22 (Y-side only) | — | **OSPF in VRF** | No (local to AS Y) |

---

## IGP Plan

| AS | IGP | Scope |
|----|-----|-------|
| AS 64512 | OSPF Area 0 | R1-R8 (all PE/P/ASBR core links) |
| AS 64513 | IS-IS Level-2 | R13-R21 (all PE/P/ASBR core links) |
| R22 (CUST_C) | OSPF in VRF | R13↔R22 only (PE-CE, VRF context) |
