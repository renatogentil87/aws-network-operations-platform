# SR Lab Topology — Reference

**Platform:** IOS-XRv 9000 + Arista vEOS CEs
**NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3

---

## Topology Design (2 domains)

```
                    LDP Domain (OSPF)              │        SR Domain (IS-IS)
                    R1, R2, R3                      │        R3, R4, R5, R6
                                                    │
         CE1                                        │                          CE2
        e1  e2                                      │
        │    │          ┌──────── R3 ────────┐      │
        │    │          │    (boundary)       │      │
        R1───┘    ┌─────┘    Gi0  Gi1  Gi2  Gi3    │
        │         │          │    │    │    │       │
        └── R2 ───┘          R1   R6   R4   R5     │
                                   │         │      │
                                   └── CE2   │      │
                                        R4───R5     │
```

---

## Node Inventory

| Router | Loopback | Domain | IGP | Transport | Role |
|--------|----------|--------|-----|-----------|------|
| R1 | 172.16.1.1/32 | LDP | OSPF Area 0 | LDP | PE (CE1) |
| R2 | 172.16.2.2/32 | LDP | OSPF Area 0 | LDP | PE (CE1 dual-homed) |
| R3 | 172.16.3.3/32 | BOTH | OSPF + IS-IS | LDP + SR | Boundary (ABR/ASBR) |
| R4 | 172.16.4.4/32 | SR | IS-IS L2 | SR-MPLS | P |
| R5 | 172.16.5.5/32 | SR | IS-IS L2 | SR-MPLS | P |
| R6 | 172.16.6.6/32 | SR | IS-IS L2 | SR-MPLS | PE (CE2) |
| CE1 | 10.1.1.1/32 | — | eBGP 65001 | — | Customer (dual-homed R1+R2) |
| CE2 | 10.2.2.2/32 | — | eBGP 65002 | — | Customer (single-homed R6) |

---

## Link Map

| From | NIC → Gi | To | NIC → Gi | Subnet | Domain |
|------|----------|-----|----------|--------|--------|
| R1 | NIC2 → Gi0 | R3 | NIC2 → Gi0 | 10.0.13.0/24 | LDP (OSPF) |
| R1 | NIC5 → Gi3 | R2 | NIC5 → Gi3 | 10.0.12.0/24 | LDP (OSPF) |
| R2 | NIC2 → Gi0 | R4 | NIC2 → Gi0 | 10.0.24.0/24 | Boundary |
| R3 | NIC3 → Gi1 | R6 | NIC3 → Gi1 | 10.0.36.0/24 | SR (IS-IS) |
| R3 | NIC4 → Gi2 | R4 | NIC4 → Gi2 | 10.0.34.0/24 | SR (IS-IS) |
| R3 | NIC5 → Gi3 | R5 | NIC5 → Gi3 | 10.0.35.0/24 | SR (IS-IS) |
| R4 | NIC3 → Gi1 | R5 | NIC3 → Gi1 | 10.0.45.0/24 | SR (IS-IS) |
| R5 | NIC4 → Gi2 | R6 | NIC4 → Gi2 | 10.0.56.0/24 | SR (IS-IS) |

### PE-CE Links

| PE | NIC → Gi | CE | Subnet | Protocol |
|----|----------|-----|--------|----------|
| R1 | NIC3 → Gi1 | CE1 e1 | 192.168.1.0/24 | eBGP 65001 |
| R2 | NIC3 → Gi1 | CE1 e2 | 192.168.2.0/24 | eBGP 65001 (dual-homed) |
| R6 | NIC2 → Gi0 | CE2 e1 | 192.168.6.0/24 | eBGP 65002 |

---

## Prefix-SID Assignments (SR Domain)

| Router | Loopback | Prefix-SID Index | Label (SRGB 16000+) |
|--------|----------|-----------------|---------------------|
| R3 | 172.16.3.3 | 3 | 16003 |
| R4 | 172.16.4.4 | 4 | 16004 |
| R5 | 172.16.5.5 | 5 | 16005 |
| R6 | 172.16.6.6 | 6 | 16006 |

---

## IS-IS NET-IDs (SR Domain)

| Router | Loopback | Padded | System-ID | NET |
|--------|----------|--------|-----------|-----|
| R3 | 172.16.3.3 | 172016003003 | 1720.1600.3003 | 49.0001.1720.1600.3003.00 |
| R4 | 172.16.4.4 | 172016004004 | 1720.1600.4004 | 49.0001.1720.1600.4004.00 |
| R5 | 172.16.5.5 | 172016005005 | 1720.1600.5005 | 49.0001.1720.1600.5005.00 |
| R6 | 172.16.6.6 | 172016006006 | 1720.1600.6006 | 49.0001.1720.1600.6006.00 |

---

## Design Rationale

- **R3 is the boundary router** — runs both OSPF (toward R1/R2) and IS-IS (toward R4/R5/R6). Runs both LDP and SR.
- **LDP domain (R1, R2, R3):** simulates a legacy SP core that hasn't migrated to SR yet.
- **SR domain (R3, R4, R5, R6):** simulates a modern SR-MPLS core.
- **R2↔R4 link:** direct connection between LDP and SR domains (for SR-over-LDP / LDP-over-SR testing).
- **CE1 dual-homed:** tests SoO and dual-PE failover across LDP+SR boundary.
- **Rich mesh in SR domain (R3↔R4, R3↔R5, R3↔R6, R4↔R5, R5↔R6):** provides multiple paths for TI-LFA testing.
- **R4↔R5 and R3↔R5 links:** can be assigned same SRLG (shared fiber duct) for SRLG protection testing.

---

## Addressing Summary

| Range | Purpose |
|-------|---------|
| 172.16.x.x/32 | Router loopbacks |
| 10.0.XY.0/24 | Core links (XY = router numbers) |
| 192.168.1.0/24 | R1↔CE1 PE-CE |
| 192.168.2.0/24 | R2↔CE1 PE-CE (dual-homed) |
| 192.168.6.0/24 | R6↔CE2 PE-CE |
| 10.1.1.0/24 | CE1 customer network |
| 10.2.2.0/24 | CE2 customer network |
