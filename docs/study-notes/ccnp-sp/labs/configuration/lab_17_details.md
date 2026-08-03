# Lab 17: EVPN — VXLAN and MPLS — Workbook

**Platform:** EVE-NG on AWS c5.metal
**Images Required:** IOS-XRv 9000 (7.x+) for EVPN-MPLS, NXOSv 9000 (9.3+) for EVPN-VXLAN
**Topology:** 8 routers — DC fabric + WAN EVPN (see below)

**⚠️ EVE-NG REQUIRED:** This lab cannot run on GNS3/Cisco 7200. EVPN requires IOS-XR, IOS-XE 16.x+, or NXOS 9.x+. Deploy on your c5.metal EVE-NG instance.

**End Goal:** A working EVPN fabric that replaces VPLS with BGP-based MAC/IP learning, supports active-active multi-homing, and integrates L2 and L3 (IRB). By the end, you understand EVPN route types, why EVPN replaces VPLS, and how it works over both VXLAN (DC) and MPLS (WAN).

---

## EVE-NG Topology — DC Fabric + WAN

```
       ┌──────────────── DC Fabric (VXLAN) ─────────────────┐
       │                                                      │
       │    Spine1 ────────────── Spine2                      │
       │   /   |   \            /   |   \                    │
       │  /    |    \          /    |    \                   │
       │ Leaf1  Leaf2  Leaf3  Leaf1 Leaf2  Leaf3            │
       │  │      │      │                                    │
       │ Host1  Host2  Host3                                 │
       │                                                      │
       └──────────────────────────┬───────────────────────────┘
                                  │ WAN (MPLS)
       ┌──────────────────────────┼───────────────────────────┐
       │                          │                            │
       │    PE-WAN1 ──── P-WAN ──── PE-WAN2                   │
       │                                                       │
       └──── WAN Core (EVPN-MPLS) ────────────────────────────┘
```

### Simplified Topology for Lab (8 nodes)

| Router | Role | Image | Loopback | Notes |
|---|---|---|---|---|
| Spine1 | VXLAN Spine/RR | NXOSv | 10.100.0.1/32 | BGP Route Reflector for EVPN |
| Spine2 | VXLAN Spine/RR | NXOSv | 10.100.0.2/32 | BGP Route Reflector for EVPN |
| Leaf1 | VTEP | NXOSv | 10.100.1.1/32 | VXLAN endpoint |
| Leaf2 | VTEP | NXOSv | 10.100.1.2/32 | VXLAN endpoint |
| Leaf3 | VTEP/DCI | NXOSv | 10.100.1.3/32 | DCI gateway to WAN |
| PE-WAN1 | WAN PE | IOS-XRv | 10.200.0.1/32 | EVPN-MPLS |
| PE-WAN2 | WAN PE | IOS-XRv | 10.200.0.2/32 | EVPN-MPLS |
| P-WAN | WAN P | IOS-XRv | 10.200.0.11/32 | SR or LDP transport |

### Link Addressing

| Link | Subnet | Notes |
|---|---|---|
| Spine1 — Leaf1 | 10.10.1.0/30 | Underlay eBGP |
| Spine1 — Leaf2 | 10.10.1.4/30 | Underlay eBGP |
| Spine1 — Leaf3 | 10.10.1.8/30 | Underlay eBGP |
| Spine2 — Leaf1 | 10.10.2.0/30 | Underlay eBGP |
| Spine2 — Leaf2 | 10.10.2.4/30 | Underlay eBGP |
| Spine2 — Leaf3 | 10.10.2.8/30 | Underlay eBGP |
| Leaf3 — PE-WAN1 | 10.10.3.0/30 | DCI interconnect |
| PE-WAN1 — P-WAN | 10.10.4.0/30 | WAN core |
| P-WAN — PE-WAN2 | 10.10.4.4/30 | WAN core |

---

## Section 1: EVPN-VXLAN Fabric (Data Centre)

### Task 1: Build the Underlay (eBGP Unnumbered or OSPF)

1. On Spines and Leafs: configure underlay routing (eBGP or OSPF)
2. All loopbacks must be reachable across the fabric
3. Verify: Leaf1 can ping Leaf2's loopback, Leaf3's loopback, etc.
4. This is the VXLAN underlay — VTEP reachability

### Task 2: Configure EVPN Overlay (iBGP with Spines as RR)

1. On Spine1/Spine2: configure BGP EVPN address-family:
   - All Leafs as RR clients under `address-family l2vpn evpn`
2. On all Leafs: iBGP to both Spines for EVPN:
   - `address-family l2vpn evpn`
   - `send-community both`
3. Verify: `show bgp l2vpn evpn summary` — all sessions UP

### Task 3: First VXLAN VNI with EVPN

1. On Leaf1: create EVPN instance for VLAN 10:
   - VNI 10010, RD auto, RT auto
   - Map VLAN 10 to VNI 10010
   - NVE interface (VTEP): `interface nve1` → `member vni 10010`
2. On Leaf2: same configuration (VLAN 10, VNI 10010)
3. Simulated hosts:
   - Leaf1: SVI for VLAN 10 or loopback simulating host (10.10.10.1/24)
   - Leaf2: loopback simulating host (10.10.10.2/24)
4. Verify: `show bgp l2vpn evpn` — Route Type 3 (Inclusive Multicast) exchanged
5. Verify: hosts on VLAN 10 can ping across the fabric (L2 extension via VXLAN)
6. Verify: `show l2route evpn mac all` — MAC addresses learned via EVPN (Type 2 routes)

### Task 4: Verify EVPN Route Types

1. `show bgp l2vpn evpn` — observe different route types:
   - **Type 2 (MAC/IP):** host MAC + optional IP advertised by the Leaf where host is connected
   - **Type 3 (Inclusive Multicast):** declares VTEP participation in a VNI (BUM handling)
   - **Type 5 (IP Prefix):** used for L3 routing (inter-subnet, external connectivity)
2. On Spine1: `show bgp l2vpn evpn route-type 2` — all MAC/IP routes
3. Compare with VPLS: VPLS floods to learn MACs (data-plane learning). EVPN advertises MACs via BGP (control-plane learning — no flooding for known MACs!)
4. Add a new "host" on Leaf1 — verify Type 2 route appears on Leaf2 within seconds (no flood needed)

---

## Section 2: EVPN IRB (Integrated Routing and Bridging)

### Task 5: Inter-Subnet Routing (Symmetric IRB)

1. On all Leafs: create SVIs for VLAN 10 (10.10.10.0/24) and VLAN 20 (10.10.20.0/24)
2. Configure L3VNI for inter-subnet routing:
   - VRF TENANT_A
   - L3VNI 50000
   - Associate VRF with L3VNI on NVE interface
3. Host1 on Leaf1 (VLAN 10, 10.10.10.1) wants to reach Host3 on Leaf3 (VLAN 20, 10.10.20.3)
4. Leaf1 routes locally (VLAN 10 → VRF → VXLAN L3VNI → Leaf3 → VLAN 20)
5. Verify: `ping 10.10.20.3 source 10.10.10.1` works
6. Verify: `show bgp l2vpn evpn route-type 5` — IP prefix routes for inter-subnet
7. **This replaces separate L3 routing** — EVPN handles both L2 bridging AND L3 routing in one control plane

### Task 6: Distributed Anycast Gateway

1. On ALL Leafs: configure same gateway IP + virtual MAC for VLAN 10:
   - SVI VLAN 10: `ip address 10.10.10.254/24`
   - `fabric forwarding anycast-gateway-mac 0000.1234.5678`
2. Every Leaf is the default gateway for hosts in VLAN 10 — no FHRP needed
3. Verify: host on any Leaf uses 10.10.10.254 as gateway — always locally routed
4. **Benefit:** no spanning-tree, no active/standby gateway, instant mobility

---

## Section 3: EVPN Multi-Homing (Active-Active)

### Task 7: Ethernet Segment (ESI) for Dual-Homed Host

1. Connect a simulated host to BOTH Leaf1 and Leaf2 (LAG or dual-attached)
2. On Leaf1 and Leaf2: configure same ESI (Ethernet Segment Identifier):
   - `evpn` → `esi 0000.0000.0000.0001.0001`
3. Both Leafs advertise **Type 1 (Ethernet Auto-Discovery)** and **Type 4 (ES)** routes
4. Verify: `show bgp l2vpn evpn route-type 1` — AD routes from both Leafs
5. Verify: `show bgp l2vpn evpn route-type 4` — ES routes establishing DF election
6. Traffic from Leaf3 to the dual-homed host: load-balanced to BOTH Leaf1 and Leaf2
7. **Compare with VPLS:** VPLS only supports active-standby for multi-homing. EVPN gives active-active with no loops.

### Task 8: Failover Testing

1. Active-active working: traffic to dual-homed host split between Leaf1 and Leaf2
2. Shut Leaf1's connection to the host
3. Verify: Leaf1 withdraws Type 1 route — all traffic shifts to Leaf2
4. Packet loss: 0-2 packets (fast MAC mass-withdrawal via Type 1)
5. Bring Leaf1 back — traffic rebalances
6. **Key EVPN advantage:** mass MAC withdrawal is ONE BGP update (Type 1 route withdrawal) vs VPLS needing individual MAC withdrawal per address

---

## Section 4: EVPN-MPLS (WAN)

### Task 9: EVPN over MPLS Transport

1. On PE-WAN1 and PE-WAN2: configure EVPN with MPLS transport (not VXLAN):
   - IS-IS + SR (or LDP) between PE-WAN1, P-WAN, PE-WAN2
   - BGP EVPN address-family between PE-WAN1 and PE-WAN2
2. Create an EVPN instance (EVI) for L2VPN service:
   ```
   evpn
    evi 100
     bgp route-target import 64512:100
     bgp route-target export 64512:100
    interface Bundle-Ether1.100
     ethernet-segment
      identifier type 0 00.00.00.00.00.00.00.01.00
   ```
3. Verify: `show evpn evi` — EVI 100 active
4. Verify: EVPN route types exchanged between PE-WAN1 and PE-WAN2
5. **Same EVPN control plane as DC** — just different transport (MPLS labels instead of VXLAN VNI)

### Task 10: DCI — Connect DC Fabric to WAN

1. Leaf3 is the DCI gateway: connects EVPN-VXLAN (DC) to PE-WAN1 (MPLS WAN)
2. Configure Leaf3 ↔ PE-WAN1 interconnect:
   - Option A: VXLAN-to-MPLS gateway on Leaf3/PE-WAN1 (re-encapsulates)
   - Option B: extend EVPN between DC and WAN (single EVPN domain, multiple transport)
3. Verify: host in DC (behind Leaf1) can reach host behind PE-WAN2 at L2
4. Verify: `show bgp l2vpn evpn` on Spine1 — sees routes from WAN domain
5. **SP use case:** enterprise with DC in one location, branches connected via MPLS WAN — single EVPN control plane, multiple transports

---

## Section 5: EVPN vs VPLS — Migration and Comparison

### Task 11: EVPN Advantages Demonstrated

1. Document every EVPN advantage you've proven in this lab:
   - Control-plane MAC learning (no flooding for known MACs) — Task 4
   - Active-active multi-homing (ESI-based) — Task 7
   - Fast convergence via mass MAC withdrawal (Type 1) — Task 8
   - Integrated L2+L3 routing (IRB) — Task 5
   - Distributed anycast gateway (no FHRP) — Task 6
   - Multi-transport (VXLAN + MPLS in same control plane) — Task 10
2. For each: note what VPLS would require instead (flooding, active-standby, separate routing, FHRP)
3. **Conclusion:** EVPN is VPLS done right — same goal (multipoint L2VPN), better implementation

### Task 12: EVPN L3VPN (Type 5 Routes)

1. EVPN can replace traditional L3VPN (vpnv4) for IP prefix distribution:
   - Type 5 (IP Prefix) routes carry IPv4/IPv6 prefixes with EVPN RTs
2. Configure IP prefix advertisement via EVPN:
   - Under VRF: redistribute connected/static into BGP EVPN
3. Verify: `show bgp l2vpn evpn route-type 5` — IP prefixes visible
4. Remote Leaf receives Type 5 route and installs in VRF routing table
5. **Future direction:** EVPN replaces BOTH vpnv4 (L3VPN) and VPLS (L2VPN) with a single protocol

---

## CCIE+ Challenges

### Challenge 1: EVPN Multi-Homing with vPC

1. Configure Leaf1 and Leaf2 in vPC pair (NXOSv):
   - vPC peer-link, vPC keepalive, vPC port-channel to dual-homed host
2. Combine with EVPN ESI — vPC provides L2 redundancy, EVPN provides control-plane awareness
3. Verify: active-active forwarding through vPC pair
4. Kill one vPC member — verify non-disruptive failover

### Challenge 2: EVPN ARP Suppression

1. Enable ARP suppression on VTEPs:
   - When a host ARPs for a known IP, the local VTEP answers from its EVPN MAC/IP table
   - No ARP flood across the fabric
2. Verify: `show l2route evpn mac-ip all` — MAC+IP bindings cached
3. Generate ARP from Host1 for Host2's IP — Leaf1 answers locally (no flood to Leaf2)
4. **Benefit:** massive reduction in BUM traffic in large DC fabrics

### Challenge 3: EVPN Route Leaking (Inter-VRF)

1. TENANT_A (VRF-A) needs to reach shared services in TENANT_B (VRF-B)
2. Configure RT import/export between EVPN instances (same concept as L3VPN RT leaking)
3. Verify: host in TENANT_A can reach service in TENANT_B
4. Verify: full isolation maintained for other prefixes

---

## Final Validation

By the end of this lab, your network has:

- [ ] EVPN-VXLAN fabric operational (Spine/Leaf with BGP EVPN overlay)
- [ ] L2 VXLAN extension between Leafs (hosts on same VLAN across fabric)
- [ ] Control-plane MAC learning via EVPN Type 2 routes (no flooding)
- [ ] EVPN Route Types understood (1, 2, 3, 4, 5)
- [ ] Inter-subnet routing via EVPN IRB (Symmetric IRB with L3VNI)
- [ ] Distributed anycast gateway (same-IP gateway on all Leafs)
- [ ] Active-active multi-homing with ESI (0 packet loss failover)
- [ ] EVPN-MPLS on WAN PEs (same control plane, MPLS transport)
- [ ] DCI connecting DC fabric to MPLS WAN
- [ ] EVPN Type 5 for IP prefix routing (L3VPN replacement concept)
- [ ] (CCIE+) vPC + EVPN multi-homing combined
- [ ] (CCIE+) ARP suppression reducing BUM traffic
- [ ] (CCIE+) Inter-VRF route leaking via EVPN RT
