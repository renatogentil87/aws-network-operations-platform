# Lab 13: Multicast VPN (mVPN) — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, CEs as multicast sources/receivers.
**Prerequisite:** Lab 2 complete (L3VPN working), PIM running capability on routers

**End Goal:** Multicast traffic from one customer site reaches all other sites in the same VPN — without leaking into other VRFs. By the end, you have a working mVPN service with multicast sources and receivers in different sites, default MDT for background traffic, and data MDT for high-bandwidth streams. This is how SPs deliver IPTV and enterprise multicast over MPLS.

**⚠️ Platform Note:** mVPN requires PIM and multicast routing on the core. Cisco 7200 supports this, but performance may be limited. Some advanced mVPN profiles (Profile 6, RSVP-TE P2MP) may not be available. The lab focuses on Profile 0 (GRE/default MDT) and Profile 1 (mLDP) where supported.

---

## Section 1: Core Multicast — PIM in the Global Table

### Task 1: Enable Multicast on the SP Core

1. On ALL P and PE routers: `ip multicast-routing`
2. On ALL core-facing interfaces (P-to-P and PE-to-P): `ip pim sparse-mode`
3. On ALL Loopback0 interfaces: `ip pim sparse-mode`
4. Designate a Rendezvous Point (RP) for the core:
   - Use R3's loopback (3.3.3.3) as static RP for ALL multicast groups
   - On ALL routers: `ip pim rp-address 3.3.3.3`
5. Verify: `show ip pim neighbor` on R2 — PIM neighbors on all core links
6. Verify: `show ip pim rp mapping` — RP is 3.3.3.3
7. **Do NOT enable PIM on PE-CE interfaces** — customer multicast stays inside VRFs

### Task 2: Verify Core Multicast Works (Global Table)

1. On R8: join a test multicast group (239.1.1.1):
   - `interface Loopback0` → `ip igmp join-group 239.1.1.1`
2. On R2: `ping 239.1.1.1 source 2.2.2.2 repeat 5` — multicast ping in global table
3. Verify: `show ip mroute 239.1.1.1` on R2 — shows (S,G) or (*,G) entry toward R3 (RP)
4. Verify: `show ip mroute 239.1.1.1` on R8 — shows entry with Loopback0 in OIL
5. Remove the IGMP join when done: `no ip igmp join-group 239.1.1.1`
6. Core multicast is working — this is the FOUNDATION for mVPN (the "underlay" for MDT)

### Task 3: Auto-RP or BSR (Dynamic RP Discovery)

1. Instead of static RP, configure Auto-RP:
   - On R3: `ip pim send-rp-announce Loopback0 scope 16`
   - On R3: `ip pim send-rp-discovery Loopback0 scope 16`
2. On all other routers: remove static `ip pim rp-address` — let them learn via Auto-RP
3. Verify: `show ip pim rp mapping` on R8 — learned R3 as RP via Auto-RP
4. Alternative: BSR (Bootstrap Router) — if preferred:
   - On R3: `ip pim bsr-candidate Loopback0`
   - On R3: `ip pim rp-candidate Loopback0`
5. Either method works — choose one for your lab
6. Verify: all routers agree on the same RP

---

## Section 2: mVPN Profile 0 — Default MDT (GRE-Based)

### Task 4: Enable Multicast Routing in VRF

1. On R2: `ip multicast-routing vrf Customer_A`
2. On R8: `ip multicast-routing vrf Customer_A`
3. On R17: `ip multicast-routing vrf Customer_A` (if R17 has Customer_A VRF)
4. On PE-CE interfaces (in VRF Customer_A): `ip pim sparse-mode`
   - R2 Fa0/0 (toward R1): `ip pim sparse-mode`
   - R8 Gi1/0 (toward R9): `ip pim sparse-mode`
5. On CEs: `ip multicast-routing` and PIM on interface toward PE
   - R1: `ip multicast-routing`, `ip pim sparse-mode` on Fa0/0
   - R9: `ip multicast-routing`, `ip pim sparse-mode` on Gi1/0
6. Verify: `show ip pim vrf Customer_A neighbor` on R2 — R1 is a PIM neighbor in the VRF

### Task 5: Configure Default MDT (Multicast Distribution Tree)

1. On R2: under VRF Customer_A configuration:
   - `mdt default 239.100.100.1` (MDT group in the GLOBAL table)
2. On R8: under VRF Customer_A configuration:
   - `mdt default 239.100.100.1` (SAME group — all PEs for this VRF join this group)
3. The MDT group (239.100.100.1) is a multicast group in the SP core — it creates a tunnel between all PEs serving Customer_A
4. Verify: `show ip mroute 239.100.100.1` on R2 — shows entry for the MDT group
5. Verify: `show ip pim vrf Customer_A mdt interface` — MDT tunnel interface created
6. Verify: `show ip mroute vrf Customer_A` — VRF multicast routing table initialized

### Task 6: Test Customer Multicast Through mVPN

1. On R9 (CE receiver): `interface Loopback0` → `ip igmp join-group 239.10.10.10`
   - R9 is requesting to receive multicast group 239.10.10.10 for Customer_A
2. On R1 (CE source): send multicast traffic:
   - `ping 239.10.10.10 source 1.1.1.1 repeat 100`
3. On R2: `show ip mroute vrf Customer_A 239.10.10.10` — should show (S,G) entry
   - Source: R1's IP (1.1.1.1), incoming interface: Fa0/0
   - Outgoing interface list: MDT tunnel (encapsulated into core multicast 239.100.100.1)
4. On R8: `show ip mroute vrf Customer_A 239.10.10.10` — should show:
   - Incoming: MDT tunnel (received from core multicast)
   - Outgoing: Gi1/0 (toward R9)
5. Verify: R9 receives the multicast packets from R1
6. **Prove isolation:** Customer_B CEs should NOT receive group 239.10.10.10

### Task 7: Verify MDT Encapsulation

1. On R2: `show ip mroute 239.100.100.1` — this shows the core-level multicast tree for the MDT
2. The customer multicast (239.10.10.10) is encapsulated inside the MDT (239.100.100.1)
3. P routers (R3, R4, etc.) only see 239.100.100.1 — they don't know about customer groups
4. On R3: `show ip mroute` — should show 239.100.100.1 (MDT) but NOT 239.10.10.10 (customer)
5. **Key insight:** P routers forward MDT traffic without any VRF or customer awareness
6. This is the same principle as L3VPN: core is unaware of customer topology

---

## Section 3: Data MDT — High-Bandwidth Stream Optimization

### Task 8: The Problem with Default MDT

1. Default MDT sends ALL customer multicast to ALL PEs in the VPN
2. If R1 sends a high-bandwidth stream (e.g., video) and only R9 wants it:
   - R17 also receives it via the default MDT (even though no one behind R17 wants it)
   - Wasted bandwidth on R2→R17 pseudowire
3. Document: default MDT = always-on flood to all PEs. Inefficient for high-rate streams.

### Task 9: Configure Data MDT (On-Demand Multicast Tree)

1. On R2: under VRF Customer_A:
   - `mdt data 239.200.200.0 0.0.0.255` (data MDT group range)
   - `mdt data threshold 1` (trigger data MDT after 1 kbps — low for lab testing)
2. On R8: same configuration:
   - `mdt data 239.200.200.0 0.0.0.255`
   - `mdt data threshold 1`
3. Generate sustained multicast from R1 to 239.10.10.10 (more than 1 kbps):
   - `ping 239.10.10.10 source 1.1.1.1 repeat 10000 size 1000 timeout 0`
4. After threshold is exceeded: R2 creates a data MDT:
   - Dynamically selects a group from the range (e.g., 239.200.200.1)
   - Only R8 (which has a receiver) joins the data MDT
   - R17 does NOT join (no receiver) — stops receiving the stream
5. Verify: `show ip mroute vrf Customer_A 239.10.10.10` on R2 — now shows data MDT interface
6. Verify: `show ip pim vrf Customer_A mdt send` — shows data MDT created
7. Verify: on R17: `show ip mroute 239.200.200.1` — R17 is NOT in the tree (bandwidth saved)

### Task 10: Data MDT Teardown

1. Stop the multicast traffic from R1
2. On R9: `no ip igmp join-group 239.10.10.10` (remove receiver)
3. Wait for data MDT timeout (default 60 seconds)
4. Verify: data MDT torn down — `show ip pim vrf Customer_A mdt send` shows empty
5. Traffic below threshold falls back to default MDT
6. **SP model:** default MDT handles low-rate signalling/control multicast. Data MDT handles high-rate video/IPTV streams efficiently.

---

## Section 4: mVPN OAM and Troubleshooting

### Task 11: Verify MDT Tunnel State

1. On R2: `show ip pim vrf Customer_A mdt interface` — MDT tunnel created
2. On R2: `show ip pim vrf Customer_A neighbor` — PIM neighbors in VRF (CE-facing)
3. On R2: `show ip mroute vrf Customer_A summary` — count of multicast routes in VRF
4. On R2: `show ip pim vrf Customer_A rp mapping` — RP for VRF multicast groups
5. **Troubleshooting checklist:**
   - Is `ip multicast-routing vrf Customer_A` enabled?
   - Is PIM sparse-mode on the CE-facing VRF interface?
   - Is the MDT group (239.100.100.1) reachable in the core (core PIM working)?
   - Does the CE have PIM enabled and IGMP join for the group?

### Task 12: Diagnose Multicast Black-Hole

1. On R8: remove `ip pim sparse-mode` from Gi1/0 (break PE-CE PIM)
2. On R9: `ip igmp join-group 239.10.10.10` — R9 wants the group
3. On R1: send multicast to 239.10.10.10
4. On R2: `show ip mroute vrf Customer_A 239.10.10.10` — traffic enters VRF
5. On R8: `show ip mroute vrf Customer_A 239.10.10.10` — outgoing interface list is EMPTY (no PIM neighbor = no path to receiver)
6. R9 doesn't receive traffic — black-hole at R8
7. Fix: re-enable `ip pim sparse-mode` on R8 Gi1/0
8. Verify: R9 now receives multicast after PIM adjacency reforms and IGMP join propagates

---

## Section 5: VRF RP Placement

### Task 13: RP Inside the VRF (CE as RP)

1. Choose R1 as RP for Customer_A multicast groups:
   - On R2 (under VRF Customer_A): `ip pim vrf Customer_A rp-address 1.1.1.1`
   - On R8 (under VRF Customer_A): `ip pim vrf Customer_A rp-address 1.1.1.1`
2. On R1: `ip pim rp-address 1.1.1.1` (R1 is the RP within its own network)
3. Verify: `show ip pim vrf Customer_A rp mapping` — RP is 1.1.1.1 (customer's RP)
4. Test: source on R9, receiver on R1 — multicast should flow correctly via RP
5. **SP model:** customer controls their own RP — SP is transparent

### Task 14: RP on the PE (SP-Managed RP)

1. Alternative: R2's VRF loopback (22.22.22.22 if in VRF) becomes RP
2. On R2: `ip pim vrf Customer_A rp-address 22.22.22.22` (PE-based RP)
3. On R8: same RP address
4. All customer PIM Register messages go to R2 (the PE RP)
5. Verify: source registration works, RPT to SPT switchover works
6. **Trade-off:** customer RP = customer controls multicast. PE RP = SP controls multicast (simpler for customer, more load on PE)

---

## CCIE+ Challenges

### Challenge 1: mVPN with Multiple Customers

1. Customer_A: MDT default 239.100.100.1
2. Customer_B: MDT default 239.100.100.2 (different MDT group — separate tree)
3. Both customers have multicast sources and receivers
4. Verify: Customer_A multicast stays in Customer_A MDT — never leaks to Customer_B
5. Verify: Customer_B multicast stays in Customer_B MDT
6. On P routers: both 239.100.100.1 and 239.100.100.2 trees exist independently
7. **Proves:** mVPN isolation is as strong as unicast VPN isolation

### Challenge 2: mVPN Profile 1 — mLDP-Based (If Supported)

1. Instead of GRE+core PIM (Profile 0), use mLDP (Multicast LDP):
   - `mdt default mpls mldp <root-address>`
   - No PIM needed in the core for mVPN — mLDP builds the tree
2. If supported on IOS 15.2:
   - Configure mLDP on all core routers
   - Replace `mdt default 239.x.x.x` with `mdt default mpls mldp 2.2.2.2`
3. Verify: MDT tree built via mLDP (no core PIM for VPN multicast)
4. Advantage: no need for core multicast routing (PIM) for VPN traffic — simplifies core
5. If not supported: document the concept and benefits over Profile 0

### Challenge 3: SSM (Source-Specific Multicast) in mVPN

1. Configure the customer multicast group range as SSM (232.0.0.0/8):
   - On PEs: `ip pim vrf Customer_A ssm default`
   - On CEs: `ip igmp version 3` + SSM join for (S,G)
2. R9 joins specific source: `ip igmp join-group 232.1.1.1 source 1.1.1.1`
3. Advantage: no RP needed for SSM — direct source-tree built immediately
4. Verify: no (*,G) state — only (S,G) state in `show ip mroute vrf Customer_A`
5. **Modern mVPN deployments prefer SSM** — more efficient, no RP dependency

### Challenge 4: mVPN + TE Tunnel (Multicast on Engineered Path)

1. Bind the MDT multicast traffic to a TE tunnel:
   - Core PIM uses the TE tunnel to forward MDT group
   - `ip pim rp-address 3.3.3.3` + `ip multicast mpls traffic-eng` (if available)
2. Alternative: use the `mdt default mpls mldp` with TE (mLDP + RSVP-TE P2MP)
3. This is advanced — likely requires IOS-XR. Document the concept if not available.
4. **SP production:** IPTV over TE-protected paths — guaranteed bandwidth + fast protection for multicast

### Challenge 5: Extranet Multicast (Cross-VRF Multicast Sharing)

1. Customer_A has a multicast source (IPTV headend)
2. Customer_B wants to receive specific channels from Customer_A
3. Design: Customer_A's MDT distributes to Customer_A sites. For Customer_B:
   - Import Customer_A's multicast routes into Customer_B's VRF (selective RT leaking for multicast)
   - OR: PE (R2) acts as multicast proxy — receives from VRF_A, re-injects into VRF_B
4. Configure and test cross-VRF multicast delivery
5. Verify: Customer_B receiver gets Customer_A's multicast stream
6. Verify: Customer_B CANNOT source multicast into Customer_A (one-way sharing)
7. **SP use case:** wholesale IPTV — content provider in one VPN, retail customers in another

---

## Final Validation

By the end of this lab, your network has:

- [ ] PIM sparse-mode running on entire SP core (global table)
- [ ] RP configured (static or Auto-RP/BSR) and all routers agree
- [ ] VRF multicast routing enabled on all PEs serving multicast customers
- [ ] Default MDT configured and operational between PEs (239.100.100.1)
- [ ] Customer multicast (source on R1, receiver on R9) working end-to-end via mVPN
- [ ] P routers unaware of customer multicast groups (only see MDT group)
- [ ] Complete mVPN isolation between customers (separate MDT groups)
- [ ] Data MDT triggered for high-bandwidth streams (bandwidth optimization)
- [ ] Data MDT torn down when stream stops (resource cleanup)
- [ ] VRF RP placement understood (customer RP vs PE RP)
- [ ] mVPN troubleshooting: can identify and fix multicast black-holes
- [ ] (CCIE+) Multiple customer mVPNs coexisting with isolation
- [ ] (CCIE+) SSM in mVPN eliminating RP dependency
- [ ] (CCIE+) Extranet multicast (cross-VRF multicast sharing concept)
