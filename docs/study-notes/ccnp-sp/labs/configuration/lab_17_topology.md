# Lab 17 — EVPN Topology (EVE-NG)

## Overview

20-router topology mirroring the GNS3 layout but adapted for EVPN with a Spine/Leaf overlay design. Uses IOS-XRv 9000 for core/PE routers and NXOSv for Leaf nodes where VXLAN-EVPN is needed.

## Platform

- **EVE-NG on AWS c5.metal**
- **PE/P/RR routers:** IOS-XRv 9000 7.x+ (SR-MPLS + MPLS-EVPN)
- **Leaf routers (optional DC extension):** NXOSv 9000 9.3+ (VXLAN-EVPN)
- **CE routers:** Linux containers (Alpine) or lightweight IOS-XRv

---

## Role Assignment (20 Routers)

| Router | Role | Platform | Description |
|--------|------|----------|-------------|
| R1 | CE | Linux/XRv-lite | Customer Edge — Customer A Site 1 |
| R2 | **PE (Leaf)** | IOS-XRv | Provider Edge — EVPN PE, dual-homed |
| R3 | **RR / Spine** | IOS-XRv | Route Reflector + P router (Spine function) |
| R4 | P | IOS-XRv | Core transit |
| R5 | P | IOS-XRv | Core transit |
| R6 | P | IOS-XRv | Core transit |
| R7 | **RR / Spine** | IOS-XRv | Route Reflector + P router (Spine function) |
| R8 | **PE (Leaf)** | IOS-XRv | Provider Edge — EVPN PE |
| R9 | CE | Linux/XRv-lite | Customer Edge — Customer A Site 2 |
| R10 | CE | Linux/XRv-lite | Customer Edge — Customer B Site 1 |
| R11 | CE | Linux/XRv-lite | Customer Edge — Customer B Site 2 |
| R12 | CE | Linux/XRv-lite | Customer Edge — Customer C Site 1 |
| R13 | P | IOS-XRv | Core transit |
| R14 | P | IOS-XRv | Core transit |
| R15 | P | IOS-XRv | Core transit |
| R16 | P | IOS-XRv | Core transit |
| R17 | **PE (Leaf)** | IOS-XRv | Provider Edge — EVPN PE, multi-homed |
| R18 | **PE (Leaf)** | IOS-XRv | Provider Edge — EVPN PE |
| R19 | CE | Linux/XRv-lite | Customer Edge — Customer C Site 2 |
| R20 | CE | Linux/XRv-lite | Customer Edge — Customer D (single-homed) |

---

## Topology Diagram

```
                        SPINE / ROUTE REFLECTOR LAYER
                    ┌──────────[R3/RR]──────────┐
                    │              │              │
                    │         [R7/RR]             │
                    │          │   │              │
                    ├──────────┼───┼──────────────┤
                    │          │   │              │
              CORE P LAYER     │   │
         ┌────[R4]────[R5]────[R6]────┐
         │    │              │    │    │
         │  [R13]──[R14]──[R15]──[R16] │
         │                              │
              PE / LEAF LAYER
    [R2/PE]        [R8/PE]        [R17/PE]        [R18/PE]
      │  │           │               │  │            │
    [R1] [R12]     [R9]           [R10] [R11]      [R19] [R20]
    CE-A1  CE-C1   CE-A2          CE-B1  CE-B2     CE-C2  CE-D
```

### Spine-Leaf Mapping

```
Spine Layer (RR):    R3, R7         ← iBGP EVPN Route Reflectors
Core Layer (P):      R4, R5, R6, R13, R14, R15, R16  ← IS-IS + SR transport
Leaf Layer (PE):     R2, R8, R17, R18  ← EVPN instances, CE-facing
CE Layer:            R1, R9, R10, R11, R12, R19, R20  ← Customer devices
```

---

## ASN Scheme

| Role | ASN | Notes |
|------|-----|-------|
| SP Core (all PE, P, RR) | **64512** | Single iBGP AS for the SP network |
| Customer A (R1, R9) | 65001 | Multi-site customer |
| Customer B (R10, R11) | 65002 | Multi-site customer |
| Customer C (R12, R19) | 65003 | Multi-site customer |
| Customer D (R20) | 65004 | Single-site customer |

---

## IP Addressing Plan

### Loopbacks (Router IDs + BGP Peering)

| Router | Loopback0 | Node SID Index | Role |
|--------|-----------|----------------|------|
| R1 | 1.1.1.1/32 | — | CE |
| R2 | 2.2.2.2/32 | 2 | PE |
| R3 | 3.3.3.3/32 | 3 | RR/Spine |
| R4 | 4.4.4.4/32 | 4 | P |
| R5 | 5.5.5.5/32 | 5 | P |
| R6 | 6.6.6.6/32 | 6 | P |
| R7 | 7.7.7.7/32 | 7 | RR/Spine |
| R8 | 8.8.8.8/32 | 8 | PE |
| R9 | 9.9.9.9/32 | — | CE |
| R10 | 10.10.10.10/32 | — | CE |
| R11 | 11.11.11.11/32 | — | CE |
| R12 | 12.12.12.12/32 | — | CE |
| R13 | 13.13.13.13/32 | 13 | P |
| R14 | 14.14.14.14/32 | 14 | P |
| R15 | 15.15.15.15/32 | 15 | P |
| R16 | 16.16.16.16/32 | 16 | P |
| R17 | 17.17.17.17/32 | 17 | PE |
| R18 | 18.18.18.18/32 | 18 | PE |
| R19 | 19.19.19.19/32 | — | CE |
| R20 | 20.20.20.20/32 | — | CE |

### SRGB (Segment Routing Global Block)

```
SRGB: 16000 – 23999
Node SID formula: 16000 + index
  R2  = 16002
  R3  = 16003
  R8  = 16008
  R17 = 16017
  R18 = 16018
  etc.
```

### Core P2P Links (IS-IS /30 subnets)

| Link | Subnet | R_x interface | R_y interface |
|------|--------|---------------|---------------|
| R2–R3 | 10.0.23.0/30 | .1 | .2 |
| R2–R4 | 10.0.24.0/30 | .1 | .2 |
| R3–R4 | 10.0.34.0/30 | .1 | .2 |
| R3–R5 | 10.0.35.0/30 | .1 | .2 |
| R3–R7 | 10.0.37.0/30 | .1 | .2 |
| R4–R5 | 10.0.45.0/30 | .1 | .2 |
| R4–R13 | 10.0.4.13/30 | .1 | .2 |
| R5–R6 | 10.0.56.0/30 | .1 | .2 |
| R5–R14 | 10.0.5.14/30 | .1 | .2 |
| R6–R7 | 10.0.67.0/30 | .1 | .2 |
| R6–R8 | 10.0.68.0/30 | .1 | .2 |
| R6–R15 | 10.0.6.15/30 | .1 | .2 |
| R7–R8 | 10.0.78.0/30 | .1 | .2 |
| R7–R16 | 10.0.7.16/30 | .1 | .2 |
| R13–R14 | 10.0.13.14/30 | .1 | .2 |
| R13–R17 | 10.0.13.17/30 | .1 | .2 |
| R14–R15 | 10.0.14.15/30 | .1 | .2 |
| R14–R17 | 10.0.14.17/30 | .1 | .2 |
| R15–R16 | 10.0.15.16/30 | .1 | .2 |
| R15–R18 | 10.0.15.18/30 | .1 | .2 |
| R16–R18 | 10.0.16.18/30 | .1 | .2 |

### PE–CE Links (Customer-facing)

| Link | Subnet | EVPN Instance | Customer |
|------|--------|---------------|----------|
| R2–R1 | 192.168.1.0/24 | EVI 100 | Customer A |
| R2–R12 | 192.168.3.0/24 | EVI 300 | Customer C |
| R8–R9 | 192.168.1.0/24 | EVI 100 | Customer A |
| R17–R10 | 192.168.2.0/24 | EVI 200 | Customer B |
| R17–R11 | 192.168.2.0/24 | EVI 200 | Customer B (multi-homed) |
| R18–R19 | 192.168.3.0/24 | EVI 300 | Customer C |
| R18–R20 | 192.168.4.0/24 | EVI 400 | Customer D |

---

## EVPN Design

### EVI (EVPN Instances)

| EVI | Customer | RD | Import RT | Export RT | Type |
|-----|----------|-----|-----------|-----------|------|
| 100 | Customer A | auto | 64512:100 | 64512:100 | VLAN-based |
| 200 | Customer B | auto | 64512:200 | 64512:200 | VLAN-based |
| 300 | Customer C | auto | 64512:300 | 64512:300 | VLAN-based |
| 400 | Customer D | auto | 64512:400 | 64512:400 | VLAN-based |

### Multi-homing (Active-Active)

| CE | Primary PE | Backup PE | ESI | DF Election |
|----|-----------|-----------|-----|-------------|
| R11 (Cust B) | R17 | R8 | 00:11:11:11:11:11:11:11:11:11 | mod-based |
| R12 (Cust C) | R2 | R17 | 00:12:12:12:12:12:12:12:12:12 | mod-based |

---

## Control Plane Summary

```
Underlay:      IS-IS (single area, level-2-only) + Segment Routing MPLS
Overlay:       MP-BGP l2vpn evpn (address-family)
RR Topology:   R3 + R7 (redundant RRs, cluster-id 1)
Peering:       All PEs peer with R3 and R7 (loopback iBGP)
Transport:     SR-MPLS labels (no LDP, no RSVP)
FRR:           TI-LFA on all core links
```

---

## Lab Objectives

1. Build IS-IS + SR underlay (same as Lab 16)
2. Configure MP-BGP EVPN overlay with R3/R7 as RRs
3. Create EVI 100 — single-homed L2 EVPN (Customer A: R1↔R9 at L2)
4. Create EVI 200 — active-active multi-homing (Customer B: R11 dual-homed to R17+R8)
5. Verify MAC learning via BGP Type-2 routes (not flooding)
6. Test BUM handling (ARP, unknown unicast) — ingress replication
7. Create EVI 300 — inter-subnet routing (IRB) with EVPN Type-5 routes
8. Verify MAC mobility (move R1 from R2 to R17 — BGP withdraws + re-advertises)
9. Test designated forwarder election for multi-homed segment
10. Compare with VPLS (Lab 11): no full mesh, no STP, control-plane learning

---

## Resource Estimate

| Component | Count | RAM each | Total RAM |
|-----------|-------|----------|-----------|
| IOS-XRv 9000 (PE/P/RR) | 13 | 5GB | 65GB |
| Linux CE (Alpine) | 7 | 512MB | 3.5GB |
| EVE-NG host overhead | 1 | 8GB | 8GB |
| **Total** | **20 nodes** | | **~77GB** |

c5.metal (192GB RAM) = comfortable with headroom for monitoring/tools.
