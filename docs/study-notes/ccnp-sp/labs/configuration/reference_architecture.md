# Reference Architecture — IP Addressing & Interface Map

**Topology:** BaseTopology (local GNS3, 24 routers, 40 links)
**Platform:** Cisco 7200, IOS 15.2
**Hostnames:** R1–R25 (R12 skipped)

---

## Hostname ↔ Role Mapping

### AS 64512 — SP Backbone West (OSPF Area 0 + LDP)

| Hostname | Loopback | Role | Notes |
|----------|----------|------|-------|
| R1 | 1.1.1.1/32 | PE | |
| R2 | 2.2.2.2/32 | PE | |
| R3 | 3.3.3.3/32 | PE | |
| R4 | 4.4.4.4/32 | P + **RR** | Route Reflector for AS 64512 |
| R5 | 5.5.5.5/32 | P | |
| R6 | 6.6.6.6/32 | P + **RR** | Route Reflector for AS 64512 |
| R7 | 7.7.7.7/32 | ASBR | Inter-AS to R20 |
| R8 | 8.8.8.8/32 | ASBR | Inter-AS to R21 |

### AS 64513 — SP Backbone East (IS-IS Level-2 + LDP)

| Hostname | Loopback | Role | Notes |
|----------|----------|------|-------|
| R13 | 13.13.13.13/32 | PE | Also OSPF PE-CE to R22 |
| R14 | 14.14.14.14/32 | PE | |
| R15 | 15.15.15.15/32 | P + **RR** | Route Reflector for AS 64513 |
| R16 | 16.16.16.16/32 | P | |
| R17 | 17.17.17.17/32 | P + **RR** | Route Reflector for AS 64513 |
| R18 | 18.18.18.18/32 | P | |
| R19 | 19.19.19.19/32 | P | |
| R20 | 20.20.20.20/32 | ASBR | Inter-AS to R7 |
| R21 | 21.21.21.21/32 | ASBR | Inter-AS to R8 |

### Customer A — AS 65001 (spans BOTH SPs via Inter-AS VPN)

| Hostname | Loopback | Connected To | Homing |
|----------|----------|-------------|--------|
| R9 | 9.9.9.9/32 | R1 + R2 (AS 64512) | Dual-homed (+ backdoor to R10) |
| R10 | 10.10.10.10/32 | R2 + R3 (AS 64512) | Dual-homed (+ backdoor to R9) |
| R23 | 23.23.23.23/32 | R13 (AS 64513) | Single-homed |
| R24 | 24.24.24.24/32 | R13 + R14 (AS 64513) | Dual-homed |

> **Customer A use cases:** SoO (R9 dual-homed), sham-link (R9↔R10 backdoor), inter-AS VPN (R9/R10 ↔ R23/R24 across both SPs)

### Customer B — AS 65002 (spans BOTH SPs via Inter-AS VPN)

| Hostname | Loopback | Connected To | Homing |
|----------|----------|-------------|--------|
| R11 | 11.11.11.11/32 | R3 (AS 64512) | Single-homed |
| R25 | 25.25.25.25/32 | R14 (AS 64513) | Single-homed |

> **Customer B use cases:** Inter-AS Options A/B/C (R11 ↔ R25 must communicate via the two SP backbones)

### Customer C — No ASN (OSPF PE-CE, VRF mode)

| Hostname | Loopback | Connected To | Protocol |
|----------|----------|-------------|----------|
| R22 | 22.22.22.22/32 | R13 (AS 64513) | **OSPF in VRF** (no BGP) |

> **Customer C use cases:** OSPF PE-CE redistribution into MP-BGP, VRF OSPF domain-id, DN-bit

---

## Interface Type Reference

All routers have this slot layout:
| Slot | Adapter | Interface Name | Speed |
|------|---------|---------------|-------|
| 0 | C7200-IO-FE | **Fa0/0** | 100M |
| 1 | PA-GE | **Gi1/0** | 1G |
| 2 | PA-GE | **Gi2/0** | 1G |
| 3 | PA-FE-TX | **Fa3/0** | 100M |
| 4 | PA-FE-TX or PA-GE | **Fa4/0** or **Gi4/0** | varies |
| 5 | PA-GE (some routers) | **Gi5/0** | 1G |

> **Routers with slot4 = PA-FE-TX:** R3, R5, R6 → interface = **Fa4/0**
> **Routers with slot4 = PA-GE:** R4 → interface = **Gi4/0**
> **Routers with slot4+5 = PA-GE:** R4 has Gi4/0 + Gi5/0

---

## AS X (64512) — Full Interface Detail

### R1 — PE (1.1.1.1)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R9 (CE) | Fa0/0 | 192.168.1.0/24 | 192.168.1.1 | 192.168.1.9 | PE-CE |
| Gi1/0 | R5 (P) | Fa0/0 | 10.1.5.0/24 | 10.1.5.1 | 10.1.5.5 | Core |
| Gi2/0 | R4 (P) | Gi4/0 | 10.1.4.0/24 | 10.1.4.1 | 10.1.4.4 | Core |

### R2 — PE (2.2.2.2)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R10 (CE) | Fa0/0 | 192.168.2.0/24 | 192.168.2.2 | 192.168.2.10 | PE-CE |
| Gi1/0 | R9 (CE) | Gi1/0 | 192.168.3.0/24 | 192.168.3.2 | 192.168.3.9 | PE-CE |
| Gi2/0 | R4 (P) | Gi2/0 | 10.2.4.0/24 | 10.2.4.2 | 10.2.4.4 | Core |
| Fa3/0 | R6 (P) | Fa4/0 | 10.2.6.0/24 | 10.2.6.2 | 10.2.6.6 | Core |
| Fa4/0 | R5 (P) | Fa4/0 | 10.2.5.0/24 | 10.2.5.2 | 10.2.5.5 | Core |

### R3 — PE (3.3.3.3)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R11 (CE) | Fa0/0 | 192.168.4.0/24 | 192.168.4.3 | 192.168.4.11 | PE-CE |
| Gi1/0 | R10 (CE) | Gi1/0 | 192.168.5.0/24 | 192.168.5.3 | 192.168.5.10 | PE-CE |
| Gi2/0 | R6 (P) | Gi1/0 | 10.3.6.0/24 | 10.3.6.3 | 10.3.6.6 | Core |
| Fa3/0 | R4 (P) | Fa3/0 | 10.3.4.0/24 | 10.3.4.3 | 10.3.4.4 | Core |

### R4 — P (4.4.4.4) — 5 interfaces

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R6 (P) | Fa0/0 | 10.4.6.0/24 | 10.4.6.4 | 10.4.6.6 | Core |
| Gi1/0 | R5 (P) | Gi1/0 | 10.4.5.0/24 | 10.4.5.4 | 10.4.5.5 | Core |
| Gi2/0 | R2 (PE) | Gi2/0 | 10.2.4.0/24 | 10.2.4.4 | 10.2.4.2 | Core |
| Fa3/0 | R3 (PE) | Fa3/0 | 10.3.4.0/24 | 10.3.4.4 | 10.3.4.3 | Core |
| Gi4/0 | R1 (PE) | Gi2/0 | 10.1.4.0/24 | 10.1.4.4 | 10.1.4.1 | Core |

### R5 — P (5.5.5.5)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R1 (PE) | Gi1/0 | 10.1.5.0/24 | 10.1.5.5 | 10.1.5.1 | Core |
| Gi1/0 | R4 (P) | Gi1/0 | 10.4.5.0/24 | 10.4.5.5 | 10.4.5.4 | Core |
| Gi2/0 | R7 (ASBR) | Gi2/0 | 10.5.7.0/24 | 10.5.7.5 | 10.5.7.7 | Core |
| Fa3/0 | R8 (ASBR) | Fa3/0 | 10.5.8.0/24 | 10.5.8.5 | 10.5.8.8 | Core |
| Fa4/0 | R2 (PE) | Fa4/0 | 10.2.5.0/24 | 10.2.5.5 | 10.2.5.2 | Core |

### R6 — P (6.6.6.6)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R4 (P) | Fa0/0 | 10.4.6.0/24 | 10.4.6.6 | 10.4.6.4 | Core |
| Gi1/0 | R3 (PE) | Gi2/0 | 10.3.6.0/24 | 10.3.6.6 | 10.3.6.3 | Core |
| Gi2/0 | R8 (ASBR) | Gi1/0 | 10.6.8.0/24 | 10.6.8.6 | 10.6.8.8 | Core |
| Fa3/0 | R7 (ASBR) | Fa3/0 | 10.6.7.0/24 | 10.6.7.6 | 10.6.7.7 | Core |
| Fa4/0 | R2 (PE) | Fa3/0 | 10.2.6.0/24 | 10.2.6.6 | 10.2.6.2 | Core |

### R7 — ASBR (7.7.7.7)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| **Fa0/0** | **R20 (Y-ASBR)** | **Fa0/0** | **10.7.20.0/24** | **10.7.20.7** | **10.7.20.20** | **Inter-AS** |
| Gi1/0 | R8 (ASBR) | Gi2/0 | 10.7.8.0/24 | 10.7.8.7 | 10.7.8.8 | Core |
| Gi2/0 | R5 (P) | Gi2/0 | 10.5.7.0/24 | 10.5.7.7 | 10.5.7.5 | Core |
| Fa3/0 | R6 (P) | Fa3/0 | 10.6.7.0/24 | 10.6.7.7 | 10.6.7.6 | Core |

### R8 — ASBR (8.8.8.8)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| **Fa0/0** | **R21 (Y-ASBR)** | **Fa0/0** | **10.8.21.0/24** | **10.8.21.8** | **10.8.21.21** | **Inter-AS** |
| Gi1/0 | R6 (P) | Gi2/0 | 10.6.8.0/24 | 10.6.8.8 | 10.6.8.6 | Core |
| Gi2/0 | R7 (ASBR) | Gi1/0 | 10.7.8.0/24 | 10.7.8.8 | 10.7.8.7 | Core |
| Fa3/0 | R5 (P) | Fa3/0 | 10.5.8.0/24 | 10.5.8.8 | 10.5.8.5 | Core |

### R9 — CE, Customer A (9.9.9.9) — Dual-homed

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R1 (PE) | Fa0/0 | 192.168.1.0/24 | 192.168.1.9 | 192.168.1.1 | PE-CE |
| Gi1/0 | R2 (PE) | Gi1/0 | 192.168.3.0/24 | 192.168.3.9 | 192.168.3.2 | PE-CE |
| Gi2/0 | R10 (CE) | Gi2/0 | 192.168.100.0/24 | 192.168.100.9 | 192.168.100.10 | Backdoor |

### R10 — CE, Customer A (10.10.10.10) — Dual-homed

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R2 (PE) | Fa0/0 | 192.168.2.0/24 | 192.168.2.10 | 192.168.2.2 | PE-CE |
| Gi1/0 | R3 (PE) | Gi1/0 | 192.168.5.0/24 | 192.168.5.10 | 192.168.5.3 | PE-CE |
| Gi2/0 | R9 (CE) | Gi2/0 | 192.168.100.0/24 | 192.168.100.10 | 192.168.100.9 | Backdoor |

### R11 — CE, Customer B (11.11.11.11) — Single-homed

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R3 (PE) | Fa0/0 | 192.168.4.0/24 | 192.168.4.11 | 192.168.4.3 | PE-CE |

---

## AS Y (64513) — Full Interface Detail

### R13 — PE (13.13.13.13)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R19 (P) | Fa3/0 | 10.13.19.0/24 | 10.13.19.13 | 10.13.19.19 | Core |
| Gi1/0 | R23 (CE) | Gi1/0 | 172.16.1.0/24 | 172.16.1.13 | 172.16.1.23 | PE-CE |
| Gi2/0 | R22 (CE) | Gi2/0 | 172.16.2.0/24 | 172.16.2.13 | 172.16.2.22 | PE-CE |
| Fa3/0 | R24 (CE) | Fa3/0 | 172.16.3.0/24 | 172.16.3.13 | 172.16.3.24 | PE-CE |

### R14 — PE (14.14.14.14)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R25 (CE) | Fa0/0 | 172.16.4.0/24 | 172.16.4.14 | 172.16.4.25 | PE-CE |
| Gi1/0 | R24 (CE) | Gi1/0 | 172.16.5.0/24 | 172.16.5.14 | 172.16.5.24 | PE-CE |
| Gi2/0 | R18 (P) | Gi2/0 | 10.14.18.0/24 | 10.14.18.14 | 10.14.18.18 | Core |
| Fa3/0 | R23 (CE) | Gi2/0 | 172.16.6.0/24 | 172.16.6.14 | 172.16.6.23 | PE-CE |

### R15 — P + RR (15.15.15.15)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R17 (P) | Gi1/0 | 10.15.17.0/24 | 10.15.17.15 | 10.15.17.17 | Core |
| Gi1/0 | R20 (ASBR) | Fa3/0 | 10.15.20.0/24 | 10.15.20.15 | 10.15.20.20 | Core |
| Gi2/0 | R21 (ASBR) | Gi2/0 | 10.15.21.0/24 | 10.15.21.15 | 10.15.21.21 | Core |

### R16 — P (16.16.16.16)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R17 (P) | Fa0/0 | 10.16.17.0/24 | 10.16.17.16 | 10.16.17.17 | Core |
| Gi2/0 | R20 (ASBR) | Gi2/0 | 10.16.20.0/24 | 10.16.20.16 | 10.16.20.20 | Core |
| Fa3/0 | R21 (ASBR) | Fa3/0 | 10.16.21.0/24 | 10.16.21.16 | 10.16.21.21 | Core |

### R17 — P (17.17.17.17)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R16 (P) | Fa0/0 | 10.16.17.0/24 | 10.16.17.17 | 10.16.17.16 | Core |
| Gi1/0 | R15 (P) | Fa0/0 | 10.15.17.0/24 | 10.15.17.17 | 10.15.17.15 | Core |
| Gi2/0 | R19 (P) | Fa0/0 | 10.17.19.0/24 | 10.17.19.17 | 10.17.19.19 | Core |
| Fa3/0 | R18 (P) | Fa0/0 | 10.17.18.0/24 | 10.17.18.17 | 10.17.18.18 | Core |

### R18 — P (18.18.18.18)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R17 (P) | Fa3/0 | 10.17.18.0/24 | 10.17.18.18 | 10.17.18.17 | Core |
| Gi1/0 | R19 (P) | Gi1/0 | 10.18.19.0/24 | 10.18.19.18 | 10.18.19.19 | Core |
| Gi2/0 | R14 (PE) | Gi2/0 | 10.14.18.0/24 | 10.14.18.18 | 10.14.18.14 | Core |

### R19 — P (19.19.19.19)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R17 (P) | Gi2/0 | 10.17.19.0/24 | 10.17.19.19 | 10.17.19.17 | Core |
| Gi1/0 | R18 (P) | Gi1/0 | 10.18.19.0/24 | 10.18.19.19 | 10.18.19.18 | Core |
| Fa3/0 | R13 (PE) | Fa0/0 | 10.13.19.0/24 | 10.13.19.19 | 10.13.19.13 | Core |

### R20 — ASBR (20.20.20.20)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| **Fa0/0** | **R7 (X-ASBR)** | **Fa0/0** | **10.7.20.0/24** | **10.7.20.20** | **10.7.20.7** | **Inter-AS** |
| Gi1/0 | R21 (ASBR) | Gi1/0 | 10.20.21.0/24 | 10.20.21.20 | 10.20.21.21 | Core |
| Gi2/0 | R16 (P) | Gi2/0 | 10.16.20.0/24 | 10.16.20.20 | 10.16.20.16 | Core |
| Fa3/0 | R15 (P) | Gi1/0 | 10.15.20.0/24 | 10.15.20.20 | 10.15.20.15 | Core |

### R21 — ASBR (21.21.21.21)

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| **Fa0/0** | **R8 (X-ASBR)** | **Fa0/0** | **10.8.21.0/24** | **10.8.21.21** | **10.8.21.8** | **Inter-AS** |
| Gi1/0 | R20 (ASBR) | Gi1/0 | 10.20.21.0/24 | 10.20.21.21 | 10.20.21.20 | Core |
| Gi2/0 | R15 (P) | Gi2/0 | 10.15.21.0/24 | 10.15.21.21 | 10.15.21.15 | Core |
| Fa3/0 | R16 (P) | Fa3/0 | 10.16.21.0/24 | 10.16.21.21 | 10.16.21.16 | Core |

### R22 — CE, Customer C (22.22.22.22) — Single-homed

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Gi2/0 | R13 (PE) | Gi2/0 | 172.16.2.0/24 | 172.16.2.22 | 172.16.2.13 | PE-CE |

### R23 — CE, Customer C (23.23.23.23) — Dual-homed

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Gi1/0 | R13 (PE) | Gi1/0 | 172.16.1.0/24 | 172.16.1.23 | 172.16.1.13 | PE-CE |
| Gi2/0 | R14 (PE) | Fa3/0 | 172.16.6.0/24 | 172.16.6.23 | 172.16.6.14 | PE-CE |

### R24 — CE, Customer D (24.24.24.24) — Dual-homed

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Gi1/0 | R14 (PE) | Gi1/0 | 172.16.5.0/24 | 172.16.5.24 | 172.16.5.14 | PE-CE |
| Fa3/0 | R13 (PE) | Fa3/0 | 172.16.3.0/24 | 172.16.3.24 | 172.16.3.13 | PE-CE |

### R25 — CE, Customer E (25.25.25.25) — Single-homed, OSPF PE-CE

| Interface | Connected To | Remote Intf | Subnet | My IP | Remote IP | Type |
|-----------|-------------|-------------|--------|-------|-----------|------|
| Fa0/0 | R14 (PE) | Fa0/0 | 172.16.4.0/24 | 172.16.4.25 | 172.16.4.14 | PE-CE |

---

## Quick Reference: Core vs PE-CE Interfaces

### AS X — Core Interfaces (OSPF + `mpls ip`)

| Router | Core Interfaces | PE-CE (no OSPF, no mpls ip) |
|--------|----------------|----------------------------|
| R1 | Gi1/0, Gi2/0 | Fa0/0 |
| R2 | Gi2/0, Fa3/0, Fa4/0 | Fa0/0, Gi1/0 |
| R3 | Gi2/0, Fa3/0 | Fa0/0, Gi1/0 |
| R4 | Fa0/0, Gi1/0, Gi2/0, Fa3/0, Gi4/0 | — |
| R5 | Fa0/0, Gi1/0, Gi2/0, Fa3/0, Fa4/0 | — |
| R6 | Fa0/0, Gi1/0, Gi2/0, Fa3/0, Fa4/0 | — |
| R7 | Gi1/0, Gi2/0, Fa3/0 | Fa0/0 (inter-AS) |
| R8 | Gi1/0, Gi2/0, Fa3/0 | Fa0/0 (inter-AS) |

### AS Y — Core Interfaces (IS-IS + `mpls ip`)

| Router | Core Interfaces | PE-CE (no IS-IS, no mpls ip) |
|--------|----------------|------------------------------|
| R13 | Fa0/0 | Gi1/0, Gi2/0, Fa3/0 |
| R14 | Gi2/0 | Fa0/0, Gi1/0, Fa3/0 |
| R15 | Fa0/0, Gi1/0, Gi2/0 | — |
| R16 | Fa0/0, Gi2/0, Fa3/0 | — |
| R17 | Fa0/0, Gi1/0, Gi2/0, Fa3/0 | — |
| R18 | Fa0/0, Gi1/0, Gi2/0 | — |
| R19 | Fa0/0, Gi1/0, Fa3/0 | — |
| R20 | Gi1/0, Gi2/0, Fa3/0 | Fa0/0 (inter-AS) |
| R21 | Gi1/0, Gi2/0, Fa3/0 | Fa0/0 (inter-AS) |

---

## Inter-AS Links (eBGP only — NO IGP, NO LDP)

| X-side | Interface | Y-side | Interface | Subnet |
|--------|-----------|--------|-----------|--------|
| R7 | Fa0/0 | R20 | Fa0/0 | 10.7.20.0/24 |
| R8 | Fa0/0 | R21 | Fa0/0 | 10.8.21.0/24 |

---

## Backdoor Link (Customer A internal, same AS 65001)

| Router | Interface | Router | Interface | Subnet |
|--------|-----------|--------|-----------|--------|
| R9 | Gi2/0 | R10 | Gi2/0 | 192.168.100.0/24 |

---

## Address Range Summary

| Range | Purpose |
|-------|---------|
| 1.1.1.1 – 8.8.8.8 | AS 64512 loopbacks (PE/P/ASBR) |
| 9.9.9.9 – 11.11.11.11 | Customer A + B CEs (X-side) |
| 13.13.13.13 – 21.21.21.21 | AS 64513 loopbacks (PE/P/ASBR) |
| 22.22.22.22 – 25.25.25.25 | Customer A + B + C CEs (Y-side) |
| 10.x.y.0/24 | All core + inter-AS links |
| 192.168.x.0/24 | X-side PE-CE links |
| 172.16.x.0/24 | Y-side PE-CE links |
| 192.168.100.0/24 | Backdoor (R9↔R10, Customer A) |

---

## VRF Design (for L3VPN labs)

| VRF Name | Customer | ASN | X-side PEs | Y-side PEs | CEs | RT |
|----------|----------|-----|-----------|-----------|-----|-----|
| CUST_A | Customer A | 65001 | R1, R2, R3 | R13, R14 | R9, R10, R23, R24 | 64512:100 / 64513:100 |
| CUST_B | Customer B | 65002 | R3 | R14 | R11, R25 | 64512:200 / 64513:200 |
| CUST_C | Customer C | — | — | R13 | R22 | 64513:300 |

> **CUST_A** spans BOTH ASes → requires Inter-AS VPN (Options A/B/C) for R9/R10 to reach R23/R24.
> **CUST_B** spans BOTH ASes → same inter-AS requirement (R11 ↔ R25).
> **CUST_C** is local to AS Y only (OSPF PE-CE, no BGP).

---

## PE-CE Protocol Summary

| CE | PE | Protocol | ASN | Notes |
|----|-----|----------|-----|-------|
| R9 | R1 + R2 | eBGP | 65001 | Dual-homed, SoO required |
| R10 | R2 + R3 | eBGP | 65001 | Dual-homed, backdoor to R9, sham-link scenario |
| R11 | R3 | eBGP | 65002 | Single-homed |
| R22 | R13 | **OSPF (VRF)** | — | No BGP, redistribute into MP-BGP |
| R23 | R13 | eBGP | 65001 | Single-homed (Y-side Customer A) |
| R24 | R13 + R14 | eBGP | 65001 | Dual-homed (Y-side Customer A) |
| R25 | R14 | eBGP | 65002 | Single-homed (Y-side Customer B) |

---

## Key Design Scenarios (mapped to labs)

| Scenario | Routers Involved | Lab(s) |
|----------|-----------------|--------|
| IGP foundation (OSPF + IS-IS + LDP) | R1-R8 (OSPF), R13-R21 (IS-IS) | Lab 01 |
| L3VPN within single AS | R1-R3 + R9/R10/R11 (X), R13-R14 + R22-R25 (Y) | Lab 02 |
| Dual-homed CE + SoO | R9 → R1 + R2 | Lab 06 |
| Backdoor + sham-link | R9 ↔ R10 (192.168.100.0/24) | Lab 06 |
| OSPF PE-CE (VRF, redistribute) | R13 ↔ R22 | Lab 02, 06 |
| Inter-AS VPN (Options A/B/C) | R7/R8 ↔ R20/R21, Customer A (R9↔R23) + B (R11↔R25) | Lab 25 |
| Unified MPLS (BGP-LU stitch) | R7/R8 ↔ R20/R21 (single-AS mode) | Lab 26 |
| MPLS-TE tunnels | R1→R3 (within AS X) | Lab 03 |
| PW / L2VPN (AToM) | R1↔R3, R13↔R14 | Lab 04-05 |
| VPLS E-LAN | R1/R2/R3 (AS X) | Lab 11 |
| L2VPN spanning both ASes | Convert one customer to L2 (e.g., change CUST_B to VPWS R3↔R14 via ASBRs) | Lab 05, 28 |
| BGP path selection | R9 dual-homed (R1+R2), compare paths | Lab 08, 21 |
| Multicast VPN | Source R9→R1, Receiver R10→R3 (within X) | Lab 13 |
| QoS end-to-end | R9→R1→core→R3→R11 | Lab 15 |
| Security (CoPP, RTBH) | All core routers | Lab 14, 34 |
| SP peering / internet edge | Use CEs as simulated transit ASes | Lab 32 |
| Automation | All 24 routers via telnet | Lab 09, 18, 19 |
