# E02: MPLS L3VPN

**Platform:** IOS-XRv 9000 on GNS3/EC2
**Topology:** `00_topology_reference.md`
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3
**Prerequisite:** E01 complete (IS-IS + LDP on Emerald, IS-IS + SR on Garnet).

**End Goal:** MP-BGP VPNv4 in both ASes. VRFs, PE-CE eBGP + OSPF. End-to-end VPN within each AS.

---

## Section 1: MP-BGP VPNv4 — Emerald

### Task 1: PCE1 as VPNv4 Route Reflector + SR-PCE Controller
1. `router bgp 65100` on ASBR1 (6.6.6.6). VPNv4 AF. Neighbors PE1(1.1.1.1), PE2(2.2.2.2), PCE1(5.5.5.5) as RR clients. All `update-source Loopback0`.
2. Verify: `show bgp vpnv4 unicast summary` — sessions Established.

### Task 2: VRF CUST_A on PE1 + PE2
1. `vrf CUST_A / rd 65100:100 / address-family ipv4 / import/export route-target 65100:100`.
2. PE1: Gi0/0/0/0 → CUST_A (CE1, 192.168.1.0/24). Gi0/0/0/1 → CUST_A (CE2, 192.168.2.0/24).
3. PE2: Gi0/0/0/1 → CUST_A (CE2, 192.168.3.0/24, dual-homed).
4. PE-CE eBGP: neighbors CE1/CE2 remote-as 65012. `as-override` (same ASN both CEs).

### Task 3: VRF CUST_B on PE2
1. `vrf CUST_B / rd 65100:200 / route-target 65100:200`.
2. PE2: Gi0/0/0/2 → CUST_B (CE3, 192.168.4.0/24, OSPF Area 0).
3. `router ospf 2 vrf CUST_B` + redistribute into BGP.

---

## Section 2: MP-BGP VPNv4 — Garnet

### Task 4: PCE as VPNv4 Route Reflector + SR-PCE Controller
1. `router bgp 65200` on PCE (17.17.17.17). VPNv4 AF. Neighbors PE3(11.11.11.11), PE4(12.12.12.12), ASBR2(16.16.16.16) as RR clients.

### Task 5: VRF CUST_A on PE3
1. `vrf CUST_A / rd 65200:100 / route-target 65200:100`.
2. PE3: Gi0/0/0/2 → CUST_A (CE4, 172.16.1.0/24, eBGP 65012).

### Task 6: VRF CUST_D on PE4
1. `vrf CUST_D / rd 65200:400 / route-target 65200:400`.
2. PE4: Gi0/0/0/0 → CUST_D (CE6, 172.16.4.0/24, OSPF Area 0).
3. `router ospf 2 vrf CUST_D` + redistribute into BGP.

*(VRF CUST_C for CE5 EVPN = Lab E13)*

---

## Section 3: End-to-End Verification

### Task 7: Within Emerald
1. CE1 `ping` CE2 (via CUST_A) → **must succeed** (as-override needed).
2. CE1 cannot reach CE3 (different VRF) → **must fail**.

### Task 8: Within Garnet
1. CE4 reachable from PE3 VRF → **works**.
2. CE4 cannot reach CE6 (different VRF) → **must fail**.

### Task 9: Cross-AS not yet
1. CE1 cannot reach CE4 → fails. Expected — Inter-AS = E06.

---

## CCIE+ Challenges
1. **SoO** on CE2 (dual-homed PE1+PE2): `set extcommunity soo 65100:902` inbound on both PEs.
2. **RT-Constraint** on PCE1 (RR): `address-family rtfilter unicast` + activate toward PE clients.
3. **BGP PIC**: `bgp additional-paths install` on PE1/PE2 under VPNv4.
4. **Maximum-prefix**: `neighbor <CE> maximum-prefix 50 80 restart 5`.

---

## Snapshot
Take: **"E02-l3vpn-working"**

## Checklist
```
[ ] Emerald: VPNv4 sessions PE1/PE2 ↔ RR PCE1 (Established)
[ ] Emerald: CUST_A on PE1+PE2; CUST_B on PE2
[ ] Emerald: CE1↔CE2 ping works (as-override); CE1↗CE3 fails (isolation)
[ ] Garnet: VPNv4 sessions PE3/PE4 ↔ RR PCE (Established)
[ ] Garnet: CUST_A on PE3; CUST_D on PE4
[ ] Cross-AS not working yet (expected)
[ ] (CCIE+) SoO, RT-Constraint, PIC, max-prefix
```

---

## Section 3: MP-BGP VPNv4 — Gold

### Task 10: ASBR3 as VPNv4 Route Reflector + PCE
1. `router bgp 65300` on ASBR3 (21.21.21.21). VPNv4 AF. Neighbors PE5, PE6, ASBR4 as RR clients.

### Task 11: VRF CUST_A on PE5 + PE6 (Customer A, AS 65012)
1. `vrf CUST_A / rd 65300:100 / route-target 65300:100`.
2. PE5: Gi0/0/0/1 → CUST_A (CE8 e0, 192.168.12.0/24). PE6: Gi0/0/0/1 → CUST_A (CE8 e1, 192.168.13.0/24).
3. PE-CE eBGP AS 65012. `as-override` (CE8 same ASN as CE1/CE2).

### Task 12: VRF CUST_B on PE5 (Customer B, AS 65013)
1. PE5: Gi0/0/0/0 → CUST_B (CE9 e0, 192.168.11.0/24, eBGP 65013).

### Task 13: VRF CUST_C on PE6 (EVPN VLAN100 — CE7, done in E13)

### Updated Verification
- CE8 ↔ PE5/PE6 in CUST_A (within Gold) ✓
- CE9 reachable in CUST_B (within Gold) ✓
- CE1 cannot reach CE8 yet (inter-AS = E06)
- 3 SPs, 3 separate VPN domains until inter-AS is configured

### Updated Checklist
```
[ ] Emerald: VPNv4 via RR PCE1; CUST_A (PE1/PE2), CUST_B (PE2)
[ ] Gold: VPNv4 via RR ASBR3; CUST_A (PE5/PE6), CUST_B (PE5)
[ ] Garnet: VPNv4 via RR PCE; CUST_A (PE3), CUST_D (PE4)
[ ] Customer A isolated per SP until inter-AS (E06)
```
