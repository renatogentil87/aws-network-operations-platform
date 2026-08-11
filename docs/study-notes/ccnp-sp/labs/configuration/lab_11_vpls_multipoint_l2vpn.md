# Lab 11: VPLS — Multipoint L2VPN — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs (R2, R8, R17, R18), 9 P routers.
**Prerequisite:** Lab 4 complete (AToM pseudowires understood), MPLS LDP running

**End Goal:** A multipoint L2VPN service where multiple customer sites share a single broadcast domain over the MPLS core — each PE acts as a virtual switch. By the end, you have a VPLS instance connecting 3+ sites with MAC learning, BUM flooding, split-horizon, and redundancy. This is how SPs deliver E-LAN (Ethernet LAN) services.

**⚠️ Platform Note:** VPLS on Cisco 7200 requires specific IOS feature sets. If commands are not available, configure as far as possible and document the concepts for each task. The design thinking transfers directly to IOS-XR/XE and your future EVE-NG lab.

---

## Section 1: First VPLS Instance — Three-Site LAN

### Task 1: Create the VFI (Virtual Forwarding Instance)

1. On R2: configure VPLS:
   - `l2 vfi CUSTOMER_A_LAN manual`
   - `vpn id 100`
   - `neighbor 8.8.8.8 encapsulation mpls`
   - `neighbor 17.17.17.17 encapsulation mpls`
2. On R8: configure VPLS:
   - `l2 vfi CUSTOMER_A_LAN manual`
   - `vpn id 100`
   - `neighbor 2.2.2.2 encapsulation mpls`
   - `neighbor 17.17.17.17 encapsulation mpls`
3. On R17: configure VPLS:
   - `l2 vfi CUSTOMER_A_LAN manual`
   - `vpn id 100`
   - `neighbor 2.2.2.2 encapsulation mpls`
   - `neighbor 8.8.8.8 encapsulation mpls`
4. Verify: `show mpls l2transport vc` on R2 — two pseudowires (to R8 and R17) should show UP
5. This creates a full-mesh of pseudowires between all three PEs — the VPLS "backbone"

### Task 2: Bind Attachment Circuits to VPLS

1. On R2: bind the CE-facing interface to the VPLS bridge domain:
   - `interface FastEthernet0/0`
   - Remove any IP/VRF config (pure L2)
   - `service instance 1 ethernet` (if EFP supported)
   - `encapsulation default`
   - `bridge-domain 100`
   - OR use: `xconnect` with VFI binding (depends on IOS version)
   - Alternative: `bridge-domain 100` → `member vfi CUSTOMER_A_LAN` + `member FastEthernet0/0`
2. On R8: bind Gi1/0 (toward R9) to bridge-domain 100
3. On R17: bind Fa3/0 (toward R19) to bridge-domain 100
4. On R1, R9, R19: configure IPs in the SAME subnet (e.g., 10.100.0.0/24):
   - R1: 10.100.0.1/24
   - R9: 10.100.0.2/24
   - R19: 10.100.0.3/24
5. Verify: R1 can ping R9 (10.100.0.2)
6. Verify: R1 can ping R19 (10.100.0.3)
7. Verify: R9 can ping R19 (10.100.0.3)
8. All three CEs are on the same broadcast domain — virtual LAN over MPLS!

### Task 3: Verify MAC Learning

1. On R1: `ping 10.100.0.2` then `show arp` — R9's MAC address learned
2. On R2: `show bridge-domain 100` (or `show l2 vfi CUSTOMER_A_LAN`) — MAC table shows:
   - R1's MAC learned on local interface (Fa0/0)
   - R9's MAC learned via pseudowire to R8
   - R19's MAC learned via pseudowire to R17
3. On R8: same check — R9's MAC is local, R1 and R19 are remote (via pseudowires)
4. Send traffic between all pairs — verify MAC table fills correctly
5. **Key concept:** each PE does MAC learning just like a physical switch — local MACs on the attachment circuit, remote MACs on pseudowires

---

## Section 2: BUM Traffic and Split-Horizon

### Task 4: Broadcast Flooding

1. On R1: send a broadcast — `ping 10.100.0.255` (or ARP for unknown host)
2. The broadcast should be received by BOTH R9 and R19 (flooded to all VPLS members)
3. On R2: the PE receives the broadcast on Fa0/0, replicates it to:
   - Pseudowire to R8 (one copy)
   - Pseudowire to R17 (one copy)
4. R8 receives and floods out Gi1/0 to R9
5. R17 receives and floods out Fa3/0 to R19
6. Verify: all CEs receive broadcasts from each other — it's a true broadcast domain

### Task 5: Split-Horizon Rule

1. **Critical rule:** when R8 receives a frame FROM the pseudowire (from R2), it DOES NOT forward it to the other pseudowire (to R17)
2. This is **split-horizon** — frames received from the VPLS mesh are only forwarded to local attachment circuits, never back into the mesh
3. Why? R2 already sent a copy directly to R17. If R8 also forwarded to R17, R17 gets duplicates.
4. Verify: on R2, send a broadcast. Check:
   - R8 receives it on PW from R2 → forwards to R9 (local AC) only
   - R8 does NOT forward it to R17 (split-horizon prevents this)
5. Verify: R17 received its copy DIRECTLY from R2's pseudowire (not via R8)
6. `show bridge-domain 100 detail` — should indicate split-horizon group for VFI pseudowires

### Task 6: Unknown Unicast Flooding

1. Clear MAC tables on all PEs: `clear bridge-domain 100 mac-table`
2. On R1: ping R9 (10.100.0.2) — first frame is unknown unicast (R2 doesn't know which PW has R9's MAC yet)
3. R2 floods the frame to ALL pseudowires AND local ACs (except source)
4. Once R9 replies, R2 learns R9's MAC on the R8 pseudowire
5. Subsequent frames to R9 are unicast-forwarded (only to R8's pseudowire, no flooding)
6. Verify: `show bridge-domain 100 mac-address-table` — R9's MAC now associated with specific PW

---

## Section 3: VPLS Scalability

### Task 7: Add a Fourth Site

1. On R18: join the VPLS instance:
   - `l2 vfi CUSTOMER_A_LAN manual`
   - `vpn id 100`
   - `neighbor 2.2.2.2 encapsulation mpls`
   - `neighbor 8.8.8.8 encapsulation mpls`
   - `neighbor 17.17.17.17 encapsulation mpls`
2. On R2, R8, R17: add `neighbor 18.18.18.18 encapsulation mpls` to their VFI
3. On R18: bind interface toward R20 to bridge-domain 100
4. On R20: configure 10.100.0.4/24
5. Verify: R20 can ping R1, R9, and R19 — fourth site joins the LAN
6. Count pseudowires: 4 PEs = N*(N-1)/2 = 6 pseudowires total
7. `show mpls l2transport vc` — all 6 pseudowires (3 per PE) should be UP

### Task 8: Full-Mesh Scaling Problem

1. Current: 4 PEs = 6 pseudowires. Each PE maintains 3 pseudowires.
2. Calculate: with 10 PEs = 45 pseudowires. 20 PEs = 190 pseudowires.
3. Every broadcast frame is replicated N-1 times by the ingress PE
4. Document: why full-mesh VPLS doesn't scale (same reason as full-mesh iBGP)
5. Solution: Hierarchical VPLS (H-VPLS) — hub-spoke pseudowire topology
6. Alternative solution: EVPN (replaces VPLS entirely — your EVE-NG future lab)

### Task 9: Hierarchical VPLS (H-VPLS) Design

1. Designate R2 as hub PE for the VPLS instance
2. R8, R17, R18 become spoke PEs:
   - Spoke PEs only need ONE pseudowire — to the hub (R2)
   - No pseudowires between spokes
3. On R8: remove neighbors R17 and R18. Keep only R2.
4. On R17: remove neighbors R8 and R18. Keep only R2.
5. On R18: remove neighbors R8 and R17. Keep only R2.
6. On R2: keep ALL neighbors (hub connects to all spokes)
7. Verify: R9 can still ping R19 — traffic goes R9→R8→(PW)→R2→(PW)→R17→R19
8. Verify: R2 acts as transit for spoke-to-spoke traffic
9. Pseudowire count: 3 (one per spoke) instead of 6. With 20 spokes: 20 instead of 190.
10. **Trade-off:** hub PE carries all transit BUM traffic — can become a bottleneck

---

## Section 4: VPLS OAM and Troubleshooting

### Task 10: MAC Table Verification

1. On R2: `show bridge-domain 100 mac-address-table` — list all learned MACs
2. Identify: which MACs are on local AC, which are on which pseudowire
3. Clear one CE's ARP (`clear arp` on R1) — watch MAC age out on remote PEs
4. Verify MAC aging timer: `show bridge-domain 100` — default aging time (typically 300s)
5. Manually set aging: `mac address-table aging-time 120`
6. Verify: MACs age out faster after traffic stops

### Task 11: Troubleshoot VPLS Connectivity

1. Break scenario: on R8, shut Gi1/0 (R9's attachment circuit)
2. On R2: R9's MAC entry eventually ages out
3. R1 tries to ping R9 — frame floods (unknown unicast) but R8 has nowhere to send it
4. Diagnostic: `show mpls l2transport vc` — VC to R8 still UP, but AC is down
5. `show bridge-domain 100 detail` on R8 — attachment circuit shows DOWN
6. Fix: bring R8 Gi1/0 back
7. Verify: R9 re-learns, pings succeed again
8. **Lesson:** VPLS PW being UP doesn't mean the service works — check AC status too

### Task 12: VPLS with QoS

1. On R2: create a service-policy for the bridge-domain:
   - Match broadcast traffic (storm control) — limit to X% of bandwidth
   - Match unicast traffic — normal forwarding
2. Apply: `bridge-domain 100` → `service-policy input STORM-CONTROL` (syntax varies)
3. If storm control on bridge-domain not supported: apply on the AC interface:
   - `storm-control broadcast level 10` on Fa0/0
4. Verify: excessive broadcast traffic is rate-limited (PE doesn't flood unlimited BUM)
5. **SP practice:** always rate-limit BUM traffic in VPLS — one chatty CE can flood the entire VPLS domain

---

## Section 5: VPLS vs EVPN — Understanding the Evolution

### Task 13: Document VPLS Limitations

1. After completing this lab, document the problems you encountered:
   - Full-mesh pseudowires don't scale (N² problem)
   - BUM flooding replicates on ingress PE (bandwidth waste)
   - No active-active multi-homing (only active-standby for CE redundancy)
   - MAC learning is data-plane (floods before learns — inefficient)
   - No IP route awareness (pure L2 — routing needs separate protocol)
2. For each problem, note how EVPN solves it:
   - EVPN uses BGP for signalling (no full-mesh PWs — uses RRs like L3VPN)
   - EVPN advertises MACs via BGP (control-plane learning — no flooding for known MACs)
   - EVPN supports active-active multi-homing (ESI-based)
   - EVPN integrates L2 and L3 (IRB — Integrated Routing and Bridging)
3. This comparison prepares you for your EVE-NG SR-EVPN lab

### Task 14: VPLS with BGP Auto-Discovery (If Supported)

1. Instead of manually configuring neighbors, use BGP auto-discovery:
   - `l2 vfi CUSTOMER_A_LAN autodiscovery bgp signaling ldp`
   - `vpn id 100`
   - `rd 64512:100`
   - `route-target export 64512:100`
   - `route-target import 64512:100`
2. PEs advertise their VPLS membership via BGP (similar to L3VPN RT concept)
3. Pseudowires are automatically established between PEs with matching VPN ID
4. Verify: adding a new PE to the VPLS only requires configuring the new PE — existing PEs auto-discover it
5. If not supported on your image: document the concept. This is the modern way to deploy VPLS.

---

## CCIE+ Challenges

### Challenge 1: VPLS Multi-Homed CE (Active-Standby)

1. Connect R1 to BOTH R2 and R8 (dual-homed to two PEs in the same VPLS)
2. Problem: if both PEs forward, R1 creates a L2 loop in the VPLS domain
3. Solution: one PE is active (forwards), the other is standby (blocks)
4. Configure redundancy:
   - R2: primary (active for R1's attachment circuit)
   - R8: standby (blocks R1's AC until R2 fails)
5. Verify: traffic from R1 only enters VPLS via R2
6. Kill R2's AC toward R1 — R8 should activate (start forwarding for R1)
7. Verify: R9 and R19 still reach R1 — failover worked
8. **EVPN solves this with active-active** — both PEs forward simultaneously with no loops

### Challenge 2: VPLS with TE Tunnel Binding

1. Bind VPLS pseudowires to specific TE tunnels:
   - In VFI neighbor config: `neighbor 8.8.8.8 encapsulation mpls pw-class PW-OVER-TE`
   - (Using the pseudowire-class with preferred-path from Lab 5)
2. Verify: VPLS traffic between R2 and R8 rides the TE tunnel
3. Verify: VPLS traffic between R2 and R17 rides a different tunnel (or LDP if no tunnel)
4. **SP model:** premium E-LAN service with traffic-engineered paths between sites

### Challenge 3: Inter-AS VPLS

1. Split topology: AS 64512 (R2, R3-R6) and AS 64513 (R7, R8, R13-R18)
2. R6 and R7 are ASBRs
3. VPLS pseudowire from R2 (AS 64512) to R8 (AS 64513) must cross AS boundary
4. Option A: back-to-back VPLS (R6 and R7 both join VPLS, stitch at boundary)
5. Verify: R1 (behind R2 in AS 64512) can reach R9 (behind R8 in AS 64513) at L2
6. Document: what are the limitations? (ASBR becomes transit for all BUM traffic)

### Challenge 4: MAC Security in VPLS

1. On R2: limit MAC addresses learned per attachment circuit:
   - `mac address-table limit maximum 10` (on bridge-domain or port)
2. On R1: create more than 10 MAC addresses (multiple loopbacks, secondary IPs)
3. Verify: R2 stops learning after 10 — new MACs are dropped
4. This prevents a single CE from overwhelming the MAC table
5. Configure MAC aging timer to 120 seconds (faster cleanup of stale entries)
6. **SP practice:** always limit per-AC MAC count to prevent table overflow attacks

---

## Final Validation

By the end of this lab, your network has:

- [ ] VPLS instance connecting 3+ CEs on the same broadcast domain
- [ ] Full-mesh pseudowires between all participating PEs
- [ ] MAC learning operational (local and remote MACs in bridge table)
- [ ] Broadcast flooding to all sites (true L2 multipoint service)
- [ ] Split-horizon preventing duplicate frames in the mesh
- [ ] Unknown unicast flooding followed by unicast MAC-based forwarding
- [ ] Fourth site added dynamically to running VPLS
- [ ] H-VPLS reducing pseudowire count (hub-spoke topology)
- [ ] MAC table troubleshooting and aging verified
- [ ] BUM storm control rate-limiting deployed
- [ ] VPLS limitations documented (preparation for EVPN migration)
- [ ] (CCIE+) Multi-homed CE with active-standby failover
- [ ] (CCIE+) VPLS pseudowires bound to TE tunnels
- [ ] (CCIE+) MAC security limiting per-AC learned addresses
