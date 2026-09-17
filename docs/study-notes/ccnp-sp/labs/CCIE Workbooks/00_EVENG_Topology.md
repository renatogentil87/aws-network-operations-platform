# CCIE SP Workbook — EVE-NG Topology (IOS-XRv + CSR1000v)

**Platform:** EVE-NG on AWS m8i.24xlarge (96 vCPU, 384GB RAM)
**Images:** IOS-XRv 9000 7.11.1 (PE/P/RR/ASBR) + CSR1000v IOS-XE 17.x (CE/RR-Garnet)
**Modeled after:** CCIE SP Practice Lab topology (Emerald + Garnet dual-SP)

---

## Topology — 20 Nodes (Two Service Providers)

```
                    EMERALD (AS 65100)                              GARNET (AS 65200)
                    SDN-based / Segment Routing                    Legacy / LDP+RSVP → migrating to SRv6
                                                                   
  ┌─────────────────────────────────────────┐    ┌─────────────────────────────────────────────┐
  │                                         │    │                                             │
  │  CE1 ─── PE1 ─── P1 ─── P2/RR1 ── ASBR1 ════ ASBR2 ── P3/RR2 ─── P4 ─── PE3 ─── CE3   │
  │  CE2 ─── PE2 ─── P1 ─┘    │             │    │            │    └─── P5 ─── PE4 ─── CE4   │
  │                            │             │    │            │                   │           │
  │                          PCE1            │    │          PCE2                CE5           │
  │                                         │    │                                             │
  └─────────────────────────────────────────┘    └─────────────────────────────────────────────┘

  Inter-AS: ASBR1 (Emerald) ═══ ASBR2 (Garnet) — eBGP peering
```

---

## Node Inventory (20 nodes)

### Emerald — AS 65100 (IOS-XR, SR-MPLS/SRv6, IS-IS)

| Node | Role | Platform | Loopback | RAM | Notes |
|------|------|----------|----------|-----|-------|
| PE1 | PE | XRv 9000 | 1.1.1.1 | 5GB | SR, L3VPN, EVPN-VPWS, QoS |
| PE2 | PE | XRv 9000 | 2.2.2.2 | 5GB | SR, L3VPN, EVPN-VPWS, QoS |
| P1 | P | XRv 9000 | 3.3.3.3 | 5GB | SR transit, TI-LFA |
| P2 | P + RR | XRv 9000 | 4.4.4.4 | 5GB | Route Reflector (VPNv4, EVPN, MVPN, Flowspec) |
| ASBR1 | ASBR | XRv 9000 | 5.5.5.5 | 5GB | Inter-AS eBGP to Garnet |
| PCE1 | PCE | XRv 9000 | 6.6.6.6 | 5GB | SR-PCE, ODN, Flex-Algo definitions |
| CE1 | CE | CSR1000v | 11.11.11.11 | 3GB | Customer A (eBGP, AS 65001) |
| CE2 | CE | CSR1000v | 12.12.12.12 | 3GB | Customer B (eBGP, AS 65002) |

### Garnet — AS 65200 (IOS-XR core + IOS-XE CEs/RR, legacy LDP → migrating)

| Node | Role | Platform | Loopback | RAM | Notes |
|------|------|----------|----------|-----|-------|
| PE3 | PE | XRv 9000 | 21.21.21.21 | 5GB | Legacy LDP → migrate to SR/SRv6 |
| PE4 | PE | XRv 9000 | 22.22.22.22 | 5GB | Legacy LDP → migrate to SR/SRv6 |
| P3 | P + RR | XRv 9000 | 23.23.23.23 | 5GB | RR on XR (Garnet) |
| P4 | P | XRv 9000 | 24.24.24.24 | 5GB | Transit |
| P5 | P | XRv 9000 | 25.25.25.25 | 5GB | Transit |
| ASBR2 | ASBR | XRv 9000 | 26.26.26.26 | 5GB | Inter-AS eBGP to Emerald |
| PCE2 | PCE | XRv 9000 | 27.27.27.27 | 5GB | SR-PCE (Garnet side) |
| RR-G | RR | CSR1000v | 28.28.28.28 | 3GB | IOS-XE RR (Garnet — matches exam) |
| CE3 | CE | CSR1000v | 31.31.31.31 | 3GB | Customer A (eBGP, AS 65001) — spans both SPs |
| CE4 | CE | CSR1000v | 32.32.32.32 | 3GB | Customer C (OSPF PE-CE) |
| CE5 | CE | CSR1000v | 33.33.33.33 | 3GB | Customer D (eBGP, AS 65003) |
| NSO | Automation | Linux VM | — | 4GB | NSO + NEDs for XR/XE |

---

## Resource Summary

| Component | Count | RAM Each | Total RAM |
|-----------|-------|----------|-----------|
| IOS-XRv 9000 | 14 | 5GB | 70GB |
| CSR1000v | 6 | 3GB | 18GB |
| Linux (NSO) | 1 | 4GB | 4GB |
| EVE-NG overhead | 1 | 8GB | 8GB |
| **Total** | **22** | | **~100GB** |

m8i.24xlarge (384GB) = **massive headroom**. You could run this topology twice.

---

## Addressing

| Scope | Range |
|-------|-------|
| Emerald loopbacks | 1.1.1.1 – 6.6.6.6 |
| Emerald CEs | 11.11.11.11 – 12.12.12.12 |
| Garnet loopbacks | 21.21.21.21 – 28.28.28.28 |
| Garnet CEs | 31.31.31.31 – 33.33.33.33 |
| Emerald core links | 10.1.x.0/24 |
| Garnet core links | 10.2.x.0/24 |
| Inter-AS link | 10.0.0.0/24 (ASBR1=.5, ASBR2=.26) |
| Emerald PE-CE | 192.168.x.0/24 |
| Garnet PE-CE | 172.16.x.0/24 |

---

## IGP Design (matches exam)

| SP | IGP | Transport | Notes |
|----|-----|-----------|-------|
| Emerald | IS-IS L2 | SR-MPLS + SRv6 | SDN-based, SR from day 1 |
| Garnet | IS-IS L2 | LDP + RSVP-TE (initial) | Legacy, migrates to SRv6 during labs |

---

## What Each Workbook Tests on This Topology

| Workbook | Emerald Tasks | Garnet Tasks |
|----------|--------------|-------------|
| 01 IS-IS | IS-IS with SR extensions | IS-IS basic (legacy) |
| 03 LDP/MPLS | — (SR replaces LDP) | LDP + RSVP-TE setup |
| 04 L3VPN | VPNv4 over SR | VPNv4 over LDP |
| 05 PE-CE | eBGP PE-CE | eBGP + OSPF PE-CE (CE4) |
| 06 Advanced VPN | Inter-AS A/B/C (ASBR1↔ASBR2), BGP-LU | Same |
| 07 L2VPN | EVPN-VPWS | AToM pseudowires (legacy) |
| 09 Segment Routing | SR-MPLS, SR-TE, SR-PCE, ODN, Flex-Algo | SRv6 migration from LDP |
| 11 BGP | BGP path control, Flowspec, RPKI | Communities, filtering |
| 12 QoS | XR QoS policy-map | XR QoS |
| MVPN | Profiles 0, 3, 11, 12, 14 | Profiles 0, 3 |
| Security | IS-IS/BGP auth, Flowspec, RTBH | Same |
| Automation | NSO → push L3VPN, BFD, SRv6 policies | Same |

---

## Customer VPN Design

| Customer | CEs | ASN | Emerald PEs | Garnet PEs | Spans Both? |
|----------|-----|-----|------------|-----------|-------------|
| Customer A | CE1 + CE3 | 65001 | PE1 | PE3 | **YES** (inter-AS VPN) |
| Customer B | CE2 | 65002 | PE2 | — | No (Emerald only) |
| Customer C | CE4 | — | — | PE4 | No (OSPF PE-CE, Garnet only) |
| Customer D | CE5 | 65003 | — | PE4 | No (Garnet only) |

---

## AI Image Prompt (for topology diagram)

> A clean, professional dual-provider network topology diagram on a dark background. LEFT side labeled "Emerald AS 65100" in green shows 6 router icons (PE1, PE2, P1, P2/RR, ASBR1, PCE1) connected in a mesh with 2 CE icons below. RIGHT side labeled "Garnet AS 65200" in orange shows 7 router icons (PE3, PE4, P3/RR, P4, P5, ASBR2, PCE2) with 3 CE icons and 1 RR icon. A thick double line connects ASBR1 to ASBR2 labeled "Inter-AS eBGP". A small Linux icon labeled "NSO" sits below connected to both sides via management. Emerald routers have a green glow (SDN/SR), Garnet routers have orange glow (legacy). Clean, minimal, 16:9 aspect ratio. Enterprise tech style.
