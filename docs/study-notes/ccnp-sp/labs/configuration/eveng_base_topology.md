# EVE-NG Base Topology — Interface Mapping Reference

## Platform
- **EVE-NG on AWS m8i.12xlarge** (48 vCPU, 192 GB RAM)
- **XRv 9000 image:** IOS-XRv 9000 7.11.1 (xrv9k-fullk9-x-7.11.1.qcow2)
- **vIOS image:** virtioa.qcow2

---

## Node Roles

| EVE-NG Node | Role | Image | Loopback0 | Prefix-SID |
|-------------|------|-------|-----------|------------|
| xrv3 | Route Reflector / Spine | XRv 9000 | 3.3.3.3/32 | 16003 |
| xrv7 | Route Reflector / Spine | XRv 9000 | 7.7.7.7/32 | 16007 |
| xrv4 | P (Core) | XRv 9000 | 4.4.4.4/32 | 16004 |
| xrv5 | P (Core) | XRv 9000 | 5.5.5.5/32 | 16005 |
| xrv6 | P (Core) | XRv 9000 | 6.6.6.6/32 | 16006 |
| xrv10 | P (Core) | XRv 9000 | 10.10.10.10/32 | 16010 |
| xrv1 | PE (Leaf) | XRv 9000 | 1.1.1.1/32 | 16001 |
| xrv8 | PE (Leaf) | XRv 9000 | 8.8.8.8/32 | 16008 |
| xrv9 | PE (Leaf) | XRv 9000 | 9.9.9.9/32 | 16009 |
| xrv2 | PE (Leaf) | XRv 9000 | 2.2.2.2/32 | 16002 |
| vIOS11 | CE (Customer A) | vIOS | 11.11.11.11/32 | — |
| vIOS14 | CE (Customer B) | vIOS | 14.14.14.14/32 | — |
| vIOS13 | CE (Customer C) | vIOS | 13.13.13.13/32 | — |
| vIOS12 | CE (Customer D) | vIOS | 12.12.12.12/32 | — |

---

## SRGB (All XRv nodes)

```
segment-routing global-block 16000 23999
```

---

## Physical Topology Diagram

```
                         RR / SPINE LAYER
              ┌─────────[xrv3]═══════════[xrv7]─────────┐
              │          │   │            │   │           │
              │          │   │            │   │           │
              ├──────────┼───┼────────────┼───┼───────────┤
              │          │   │            │   │           │
              │     CORE P LAYER         │   │           │
         [xrv4]────[xrv5]─────[xrv6]    │   │           │
           │  │       │         │   │    │   │           │
           │  │       │       [xrv10]    │   │           │
           │  │       │      ╱  │  │ ╲   │   │           │
           │  │       │     │   │  │  │  │   │           │
              PE / LEAF LAYER
    [xrv1]        [xrv8]        [xrv9]        [xrv2]
      │              │               │            │
   [vIOS11]       [vIOS14]       [vIOS13]     [vIOS12]
```

---

## Interface-to-Interface Links (from EVE-NG screenshot)

### RR-to-RR Link
| Link | Node A | Interface A | Node B | Interface B | Subnet |
|------|--------|-------------|--------|-------------|--------|
| 1 | xrv3 | Gi0/0/0/0 | xrv7 | Gi0/0/0/0 | 10.0.37.0/30 |

### RR-to-Core Links
| Link | Node A | Interface A | Node B | Interface B | Subnet |
|------|--------|-------------|--------|-------------|--------|
| 2 | xrv3 | Gi0/0/0/2 | xrv4 | Gi0/0/0/2 | 10.0.34.0/30 |
| 3 | xrv3 | Gi0/0/0/1 | xrv5 | Gi0/0/0/1 | 10.0.35.0/30 |
| 4 | xrv3 | Gi0/0/0/3 | xrv10 | Gi0/0/0/1 | 10.0.310.0/30 |
| 5 | xrv7 | Gi0/0/0/2 | xrv5 | Gi0/0/0/2 | 10.0.75.0/30 |
| 6 | xrv7 | Gi0/0/0/4 | xrv6 | Gi0/0/0/4 | 10.0.76.0/30 |
| 7 | xrv7 | Gi0/0/0/1 | xrv10 | Gi0/0/0/0 | 10.0.710.0/30 |

### Core-to-Core Links
| Link | Node A | Interface A | Node B | Interface B | Subnet |
|------|--------|-------------|--------|-------------|--------|
| 8 | xrv4 | Gi0/0/0/1 | xrv5 | Gi0/0/0/0 | 10.0.45.0/30 |
| 9 | xrv5 | Gi0/0/0/3 | xrv6 | Gi0/0/0/3 | 10.0.56.0/30 |
| 10 | xrv5 | Gi0/0/0/4 | xrv10 | Gi0/0/0/4 | 10.0.510.0/30 |
| 11 | xrv6 | Gi0/0/0/0 | xrv10 | Gi0/0/0/3 | 10.0.610.0/30 |

### Core-to-PE Links
| Link | Node A | Interface A | Node B | Interface B | Subnet |
|------|--------|-------------|--------|-------------|--------|
| 12 | xrv4 | Gi0/0/0/0 | xrv1 | Gi0/0/0/1 | 10.0.41.0/30 |
| 13 | xrv4 | Gi0/0/0/3 | xrv8 | Gi0/0/0/3 | 10.0.48.0/30 |
| 14 | xrv10 | Gi0/0/0/2 | xrv8 | Gi0/0/0/2 | 10.0.108.0/30 |
| 15 | xrv10 | Gi0/0/0/3 | xrv9 | Gi0/0/0/3 | 10.0.109.0/30 |
| 16 | xrv10 | Gi0/0/0/4 | See link 10 (xrv5) | — | — |
| 17 | xrv6 | Gi0/0/0/1 | xrv9 | Gi0/0/0/1 | 10.0.69.0/30 |
| 18 | xrv6 | Gi0/0/0/2 | xrv2 | Gi0/0/0/2 | 10.0.62.0/30 |
| 19 | xrv7 | Gi0/0/0/3 | xrv2 | Gi0/0/0/3 | 10.0.72.0/30 |

### PE-to-CE Links
| Link | Node A | Interface A | Node B | Interface B | Subnet |
|------|--------|-------------|--------|-------------|--------|
| 20 | xrv1 | Gi0/0/0/0 | vIOS11 | Gi0/0 | 192.168.11.0/30 |
| 21 | xrv8 | Gi0/0/0/0 | vIOS14 | Gi0/0 | 192.168.14.0/30 |
| 22 | xrv9 | Gi0/0/0/0 | vIOS13 | Gi0/0 | 192.168.13.0/30 |
| 23 | xrv2 | Gi0/0/0/0 | vIOS12 | Gi0/0 | 192.168.12.0/30 |

---

## IP Addressing Summary

### Core Links (IS-IS enabled, SR enabled)

| Subnet | .1 address | .2 address |
|--------|-----------|-----------|
| 10.0.37.0/30 | xrv3 Gi0/0/0/0 | xrv7 Gi0/0/0/0 |
| 10.0.34.0/30 | xrv3 Gi0/0/0/2 | xrv4 Gi0/0/0/2 |
| 10.0.35.0/30 | xrv3 Gi0/0/0/1 | xrv5 Gi0/0/0/1 |
| 10.0.310.0/30 | xrv3 Gi0/0/0/3 | xrv10 Gi0/0/0/1 |
| 10.0.75.0/30 | xrv7 Gi0/0/0/2 | xrv5 Gi0/0/0/2 |
| 10.0.76.0/30 | xrv7 Gi0/0/0/4 | xrv6 Gi0/0/0/4 |
| 10.0.710.0/30 | xrv7 Gi0/0/0/1 | xrv10 Gi0/0/0/0 |
| 10.0.45.0/30 | xrv4 Gi0/0/0/1 | xrv5 Gi0/0/0/0 |
| 10.0.56.0/30 | xrv5 Gi0/0/0/3 | xrv6 Gi0/0/0/3 |
| 10.0.510.0/30 | xrv5 Gi0/0/0/4 | xrv10 Gi0/0/0/4 |
| 10.0.610.0/30 | xrv6 Gi0/0/0/0 | xrv10 Gi0/0/0/3 |
| 10.0.41.0/30 | xrv4 Gi0/0/0/0 | xrv1 Gi0/0/0/1 |
| 10.0.48.0/30 | xrv4 Gi0/0/0/3 | xrv8 Gi0/0/0/3 |
| 10.0.108.0/30 | xrv10 Gi0/0/0/2 | xrv8 Gi0/0/0/2 |
| 10.0.109.0/30 | xrv10 Gi0/0/0/3 | xrv9 Gi0/0/0/3 |
| 10.0.69.0/30 | xrv6 Gi0/0/0/1 | xrv9 Gi0/0/0/1 |
| 10.0.62.0/30 | xrv6 Gi0/0/0/2 | xrv2 Gi0/0/0/2 |
| 10.0.72.0/30 | xrv7 Gi0/0/0/3 | xrv2 Gi0/0/0/3 |

### PE-CE Links (NOT in IS-IS, customer-facing)

| Subnet | PE side (.1) | CE side (.2) |
|--------|-------------|-------------|
| 192.168.11.0/30 | xrv1 Gi0/0/0/0 | vIOS11 Gi0/0 |
| 192.168.14.0/30 | xrv8 Gi0/0/0/0 | vIOS14 Gi0/0 |
| 192.168.13.0/30 | xrv9 Gi0/0/0/0 | vIOS13 Gi0/0 |
| 192.168.12.0/30 | xrv2 Gi0/0/0/0 | vIOS12 Gi0/0 |

---

## Control Plane Design

| Layer | Protocol | Nodes |
|-------|----------|-------|
| Underlay IGP | IS-IS level-2-only (single area) | All 10 XRv nodes |
| Transport | Segment Routing MPLS (SRGB 16000-23999) | All 10 XRv nodes |
| Protection | TI-LFA (all core interfaces) | All 10 XRv nodes |
| Overlay | MP-BGP L2VPN EVPN | PEs (xrv1,2,8,9) ↔ RRs (xrv3,7) |
| VPN | EVPN EVI per customer | PEs only |
| CE Peering | eBGP (PE-CE) | PEs ↔ CEs |

### BGP Peering (iBGP, AS 64512)

```
xrv1 (PE) ──── iBGP ────→ xrv3 (RR)
xrv1 (PE) ──── iBGP ────→ xrv7 (RR)
xrv2 (PE) ──── iBGP ────→ xrv3 (RR)
xrv2 (PE) ──── iBGP ────→ xrv7 (RR)
xrv8 (PE) ──── iBGP ────→ xrv3 (RR)
xrv8 (PE) ──── iBGP ────→ xrv7 (RR)
xrv9 (PE) ──── iBGP ────→ xrv3 (RR)
xrv9 (PE) ──── iBGP ────→ xrv7 (RR)

All sessions use loopback peering (source Loopback0)
RRs reflect routes between all PE clients
P routers do NOT run BGP — only IS-IS + SR
```

### Customer Assignments

| Customer | EVI | CE | PE | RT |
|----------|-----|----|----|-----|
| Customer A | 100 | vIOS11 | xrv1 | 64512:100 |
| Customer B | 200 | vIOS14 | xrv8 | 64512:200 |
| Customer C | 300 | vIOS13 | xrv9 | 64512:300 |
| Customer D | 400 | vIOS12 | xrv2 | 64512:400 |

---

## Resource Estimate

| Component | Count | vCPU each | RAM each | Total vCPU | Total RAM |
|-----------|-------|-----------|----------|------------|-----------|
| XRv 9000 | 10 | 4 | 16 GB | 40 | 160 GB |
| vIOS (CE) | 4 | 1 | 2 GB | 4 | 8 GB |
| EVE-NG host | 1 | — | — | 4 | 24 GB |
| **Total** | **14** | | | **48** | **192 GB** |

**Instance: m8i.12xlarge (48 vCPU, 192 GB) — fits exactly.**
