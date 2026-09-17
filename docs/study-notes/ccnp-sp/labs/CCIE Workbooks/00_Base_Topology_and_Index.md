# CCIE Service Provider Workbooks — Base Topology & Addressing

**Style:** INE CCIE Advanced Technology Labs format — **Note → Task → Configuration (the "why") → Verification**. Progressive scenarios building on each other.
**Scope:** ADVANCED workbooks (post-foundation). Complete `labs/configuration/` set first, then use these to test knowledge under pressure.

## Two Platforms

| Platform | Topology | Purpose |
|----------|----------|---------|
| **GNS3 Local (7200)** | 24-router, R1-R25 (`gns3_base_topology.md`) | Learn protocols, concept mastery |
| **EVE-NG (IOS-XRv + CSR1000v)** | 20-node Emerald+Garnet (`00_EVENG_Topology.md`) | **CCIE exam prep** — XR syntax, SR, EVPN, QoS, MVPN, NSO |

> **The CCIE workbook should be done on EVE-NG.** The exam is 100% IOS-XR/XE. Use the Emerald+Garnet topology which mirrors the actual exam environment.

---

## The Base Topology

Same 24-router two-AS topology from `gns3_base_topology.md`. All workbooks use these names:

```
              AS X (64512)                          AS Y (64513)
                                                    
X-CE1 ─┬─ X-PE1(RR) ── X-P2 ─┬─ X-ASBR1 ══ Y-ASBR1 ─┬─ Y-P2(RR) ── Y-P3 ─┬─ Y-P5 ── Y-PE1 ─┬─ Y-CE1
(dual)  │           └── X-P1 ─┤         ×              ├─ Y-P1(RR)           ├─ Y-P4 ── Y-PE2 ─┼─ Y-CE4(OSPF)
  │     │                │    │          │              │                     │           │      │
  │     ├─ X-PE2(RR)─── X-P2  ├─ X-ASBR2 ══ Y-ASBR2 ─┘                    │           ├─ Y-CE3
  │     │   │        └── X-P3─┘                                             │           └─ Y-CE2
  │     │   │             │                                                  │
X-CE2 ──┤   └─────────────┘                                                 │
(dual)  │                                                                    │
        └── X-PE3 ─── X-P3                                                  │
                 └─── X-P1                                                   │
X-CE3 ──── X-PE3

Backdoor: X-CE1 ──── X-CE2 (same customer AS 65001)
```

---

## Router-to-Workbook Role Mapping

| Workbook Role | Actual Router | Notes |
|---------------|---------------|-------|
| PE1 | X-PE1 | PE + RR (AS X) |
| PE2 | X-PE2 | PE + RR (AS X) |
| PE3 | X-PE3 | PE (AS X) |
| PE4 | Y-PE1 | PE (AS Y) |
| PE5 | Y-PE2 | PE (AS Y) |
| P1 | X-P1 | P (AS X) |
| P2 | X-P2 | P (AS X) |
| P3 | X-P3 | P (AS X) |
| P4/P5/P6 | Y-P3/P4/P5 | P (AS Y) |
| RR1 | X-PE1 | RR on PE (AS X) |
| RR2 | X-PE2 | RR on PE (AS X) |
| RR3 | Y-P1 | RR on P (AS Y) |
| RR4 | Y-P2 | RR on P (AS Y) |
| ASBR1 | X-ASBR1 | Inter-AS border (X side) |
| ASBR2 | X-ASBR2 | Inter-AS border (X side) |
| ASBR3 | Y-ASBR1 | Inter-AS border (Y side) |
| ASBR4 | Y-ASBR2 | Inter-AS border (Y side) |
| CE1 | X-CE1 | Dual-homed, Customer A (AS 65001) |
| CE2 | X-CE2 | Dual-homed, Customer A (AS 65001), backdoor to CE1 |
| CE3 (R11) | Single-homed, Customer B (AS 65002) — spans both SPs (R25 on Y-side) |
| CE4 (R22) | OSPF PE-CE, Customer C (no ASN, VRF OSPF with R13) (AS 65003) |
| CE5 (R23) | Customer A (AS 65001) — Y-side, single-homed to R13 (AS 65003) |
| CE6 (R24) | Customer A (AS 65001) — Y-side, dual-homed R13+R14 (AS 65004) |
| CE7 (R25) | Customer B (AS 65002) — Y-side, single-homed to R14 PE-CE** |

---

## Addressing (same as labs)

- **Loopbacks:** n.n.n.n/32 (see `gns3_base_topology.md` for full table)
- **Core links:** 10.x.y.0/24
- **X PE-CE:** 192.168.x.y.0/24
- **Y PE-CE:** 172.16.x.y.0/24
- **Inter-AS:** 10.7.20.0/24 (X-ASBR1↔Y-ASBR1), 10.8.21.0/24 (X-ASBR2↔Y-ASBR2)

---

## Workbook Index

| # | Workbook | Focus | Key Routers |
|---|----------|-------|-------------|
| 01 | IS-IS as the SP IGP | IS-IS L1/L2, wide metrics, auth, overload | AS Y (all IS-IS), migrate AS X |
| 02 | OSPF as the SP IGP | Multi-area, summarization, stub/NSSA, MPLS interaction | AS X (OSPF), multi-area split |
| 03 | LDP & MPLS Forwarding | LDP operations, label allocation, PHP, session protection | Both ASes |
| 04 | MPLS L3VPN (MP-BGP VPNv4) | VRF, RD/RT, MP-BGP, RRs, label stack | All PEs + RRs |
| 05 | L3VPN PE-CE Routing | eBGP, OSPF (sham-link), static, redistribution | PEs + CEs |
| 06 | Advanced L3VPN | Inter-AS A/B/C, shared services, extranet, SoO, hub-spoke | ASBRs + PEs |
| 07 | L2VPN AToM / VPWS | Pseudowires, interworking, PW-over-TE, multi-segment | X-PE1↔X-PE3, S-PE X-P2 |
| 08 | VPLS / H-VPLS | E-LAN, BGP-AD, MAC learning, H-VPLS hub/spoke | X-PE1/PE2/PE3 |
| 09 | Segment Routing (SR-MPLS) | Prefix-SID, adj-SID, SR-TE, TI-LFA, Flex-Algo concept | AS Y (IS-IS+SR) |
| 10 | — (reserved for EVPN) | | |
| 11 | BGP Path Control & RR Scalability | Path selection, communities, Add-Path, PIC, hierarchical RR | X-CE1 dual-homed, RRs |
| 12 | SP QoS (DiffServ) | Classification, DSCP→EXP, LLQ/CBWFQ, policing, Pipe model | X-CE1→X-PE1→core→X-PE3→X-CE3 |

---

## How to Use These Workbooks

1. **Read the scenario** (initial state + requirements).
2. **Configure from scratch** — no looking at solutions until you try.
3. **Verify** using the exact commands listed.
4. **Time yourself** — CCIE gives you 5 hours for DOO (deploy/operate/optimize). Target ~30-45 min per workbook section.
5. **Progressive** — each task builds on the previous. Don't skip.

---

## Relationship to Labs

| Labs (`configuration/`) | Workbooks (`CCIE Workbooks/`) |
|------------------------|-------------------------------|
| **Learn** the technology | **Test** your knowledge |
| Guided (what to configure + how to verify) | Scenario-based (figure it out yourself) |
| Do first | Do after labs are complete |
| One technology per lab | Combines multiple technologies |
