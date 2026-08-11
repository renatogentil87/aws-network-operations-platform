# Lab 5: AToM Tunnel Selection & Advanced L2VPN — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers. Pseudowires from Lab 4 operational.
**Prerequisite:** Lab 4 complete (basic pseudowires working), Lab 3 Sections 1-2 complete (TE tunnels understood)

**End Goal:** Pseudowire traffic rides specific TE tunnels with engineered paths, pseudowires have redundancy with automatic failover, and you can mix L2VPN interworking modes. By the end, you have the full SP L2VPN toolkit: traffic-engineered pseudowires with protection — the same architecture that carriers use for Carrier Ethernet services.

---

## Section 1: Bind Pseudowires to TE Tunnels

### Task 1: Create a TE Tunnel for Pseudowire Traffic

1. On R2: create a TE tunnel to R8 specifically for L2VPN traffic:
   - `interface Tunnel20`
   - `ip unnumbered Loopback0`
   - `tunnel mode mpls traffic-eng`
   - `tunnel destination 8.8.8.8`
   - `tunnel mpls traffic-eng path-option 1 explicit name VIA-R4`
   - `tunnel mpls traffic-eng bandwidth 50000`
   - Do NOT configure `autoroute announce` — this tunnel is dedicated to pseudowires
2. Verify: Tunnel20 is UP — `show mpls traffic-eng tunnels tunnel20`
3. Note: without autoroute, this tunnel doesn't attract any traffic by default. It just exists.

### Task 2: Bind Pseudowire to the TE Tunnel (Preferred Path)

1. On R2: create a pseudowire-class that uses the TE tunnel:
   - `pseudowire-class PW-OVER-TE`
   - `encapsulation mpls`
   - `preferred-path interface Tunnel20`
2. Reconfigure the pseudowire on Fa0/0 (or sub-interface) to use this class:
   - `xconnect 8.8.8.8 100 pw-class PW-OVER-TE`
3. Verify: `show mpls l2transport vc 100 detail` — look for "preferred path: Tunnel20"
4. Verify: the pseudowire is UP and bound to the TE tunnel
5. From R1: traceroute to R9 — traffic should follow Tunnel20's explicit path (R3→R4→R5→R8)
6. Compare: change the TE tunnel to path VIA-R6 — does the pseudowire traffic move? (Yes — it follows the tunnel)

### Task 3: Verify Traffic Is on the Tunnel

1. On R2: `show mpls traffic-eng tunnels tunnel20` — check "packets/bytes switched"
2. From R1: ping R9 with 1000 packets — `ping 10.0.0.2 repeat 1000`
3. Check Tunnel20 counters again — packets switched should increase by ~1000
4. On R3 (transit router for VIA-R4): `show interfaces Fa0/0 | include packets` — confirm traffic flows through this path
5. On R6 (NOT in VIA-R4 path): verify no pseudowire traffic transits here
6. **Proves:** pseudowire traffic is pinned to the TE tunnel path — not following IGP shortest path

### Task 4: Fallback When Tunnel Goes Down

1. Current config: `preferred-path interface Tunnel20`
2. On R2: shut a link in Tunnel20's path (e.g., shut R4's Gi1/0 toward R5)
3. Tunnel20 should go DOWN (if no backup path-option configured)
4. Check: `show mpls l2transport vc 100` — does the pseudowire go DOWN too, or does it fall back to LDP path?
5. Default behaviour: pseudowire falls back to regular LDP path when preferred tunnel is down
6. Verify: R1 can still ping R9 — pseudowire survives tunnel failure via LDP fallback
7. To DISABLE fallback (strict mode): `preferred-path interface Tunnel20 disable-fallback`
8. With disable-fallback: shut the tunnel — pseudowire goes DOWN completely
9. Bring tunnel back — pseudowire recovers
10. **Design choice:** fallback = higher availability. Disable-fallback = strict path control (traffic only flows on engineered path or not at all)

---

## Section 2: Separate Pseudowires on Separate Tunnels

### Task 5: Voice and Data Pseudowires on Different Paths

1. Create two TE tunnels on R2 to R8:
   - Tunnel21: explicit path VIA-R4 (R3→R4→R5→R8), bandwidth 20000, priority 1 1
   - Tunnel22: explicit path VIA-R6 (R6→R7→R8), bandwidth 50000, priority 7 7
2. Create two pseudowire classes:
   - `pseudowire-class PW-VOICE` → `preferred-path interface Tunnel21`
   - `pseudowire-class PW-DATA` → `preferred-path interface Tunnel22`
3. On R2, use VLAN-based sub-interfaces:
   - Fa0/0.10 (VLAN 10): `xconnect 8.8.8.8 1010 pw-class PW-VOICE` (voice circuit)
   - Fa0/0.20 (VLAN 20): `xconnect 8.8.8.8 1020 pw-class PW-DATA` (data circuit)
4. On R8: mirror with matching sub-interfaces and xconnects (same VC IDs)
5. On R1/R9: configure matching VLAN sub-interfaces
6. Verify: both pseudowires UP, each bound to different tunnel
7. Verify: voice traffic (VLAN 10) goes R3→R4→R5→R8
8. Verify: data traffic (VLAN 20) goes R6→R7→R8
9. **SP model:** Carrier Ethernet with differentiated SLAs — premium voice circuit gets protected path, bulk data gets best-effort path

### Task 6: Prove Path Independence

1. Kill a link in Tunnel21's path (R4→R5)
2. Voice pseudowire (VC 1010): falls back to LDP or goes DOWN (depending on disable-fallback)
3. Data pseudowire (VC 1020): completely unaffected — still on Tunnel22
4. Bring link back — voice pseudowire recovers to its TE tunnel
5. Kill a link in Tunnel22's path (R6→R7)
6. Data pseudowire affected, voice pseudowire unaffected
7. **Proves:** separate tunnels provide fault isolation between L2VPN services

---

## Section 3: Pseudowire Redundancy

### Task 7: Backup Pseudowire (Redundant PE)

1. **Scenario:** R1 has a primary circuit to R9 via R2↔R8. Backup via R17↔R18.
2. On R2 (primary PE): configure primary xconnect:
   - `interface FastEthernet0/0`
   - `xconnect 8.8.8.8 100 encapsulation mpls`
   - `backup peer 18.18.18.18 100` (backup pseudowire to R18)
   - `backup delay 0 0` (switch immediately on failure, restore immediately on recovery)
3. On R8 (primary remote PE): standard xconnect VC 100 toward R9
4. On R18 (backup remote PE): configure xconnect VC 100 on interface toward R20
   - This is the backup endpoint — only active when primary fails
5. Verify: `show mpls l2transport vc 100 detail` on R2 — primary active, backup standby
6. Verify: R1 can ping R9 via primary path

### Task 8: Force Failover to Backup

1. On R8: shut Gi1/0 (break the primary pseudowire's remote attachment circuit)
2. On R2: `show mpls l2transport vc 100` — primary should show DOWN
3. Verify: backup pseudowire activates — `show mpls l2transport vc 100 detail` shows backup ACTIVE
4. R1 can now ping R20 (the backup remote site) — or R9 if you've connected it to R18
5. Count packet loss during switchover — how many pings were lost?
6. Bring R8's interface back — verify primary recovers and backup returns to standby
7. Verify: `show mpls l2transport vc 100 detail` — primary active again

### Task 9: Pseudowire Redundancy with TE Tunnel Protection

1. Combine: primary pseudowire on Tunnel21 (R2→R8 via VIA-R4)
2. Backup pseudowire on separate path (to R18 via normal LDP or separate tunnel)
3. Add FRR to Tunnel21 (from Lab 3 Challenge 1):
   - `tunnel mpls traffic-eng fast-reroute` on Tunnel21
   - Backup tunnel on transit router
4. Now you have three layers of protection:
   - **Layer 1:** FRR protects the tunnel (sub-50ms link failure recovery)
   - **Layer 2:** Tunnel path-option failover (2-5 second tunnel reroute)
   - **Layer 3:** Backup pseudowire to different PE (full PE failure recovery)
5. Test each layer independently:
   - Kill one core link → FRR activates (0-1 packets lost)
   - Kill entire tunnel path → pseudowire falls back to LDP or backup PW activates
   - Kill the primary PE (R8) → backup pseudowire to R18 activates
6. **This is production-grade L2VPN protection**

---

## Section 4: Pseudowire Interworking

### Task 10: VLAN ID Rewrite (Different VLANs at Each End)

1. Customer A uses VLAN 100 at Site 1 (R1 side)
2. Customer A uses VLAN 200 at Site 2 (R9 side) — different VLAN ID, same customer
3. On R2: `interface Fa0/0.100` — encapsulation dot1Q 100, xconnect 8.8.8.8 500
4. On R8: `interface Gi1/0.200` — encapsulation dot1Q 200, xconnect 2.2.2.2 500
5. The pseudowire carries the payload — VLAN tags are stripped at ingress PE and new tag applied at egress
6. Verify: R1 (VLAN 100) can communicate with R9 (VLAN 200)
7. `show mpls l2transport vc 500 detail` — note "local VLAN 100, remote VLAN 200"
8. **SP use case:** customer doesn't need to coordinate VLAN IDs between sites — SP handles translation

### Task 11: Port Mode vs VLAN Mode

1. **Port mode** (current Task 1 setup): entire physical port is the pseudowire
   - `interface FastEthernet0/0` → `xconnect ...`
   - ALL traffic on this port goes into ONE pseudowire (tagged and untagged)
2. **VLAN mode** (Task 6 setup): specific VLANs map to specific pseudowires
   - `interface FastEthernet0/0.10` → `xconnect ... vc 1010`
   - `interface FastEthernet0/0.20` → `xconnect ... vc 1020`
   - Different VLANs = different services
3. Convert VC 100 from port mode to VLAN mode:
   - Remove xconnect from Fa0/0
   - Create Fa0/0.100 with dot1Q 100 and xconnect
4. Verify: only VLAN 100 traffic crosses the pseudowire now
5. Untagged traffic on Fa0/0 is no longer carried — only the specific VLAN
6. **SP service mapping:** Port mode = EPL (Ethernet Private Line). VLAN mode = EVPL (Ethernet Virtual Private Line).

### Task 12: QinQ (802.1ad) Access Mode

1. On R2: configure the CE-facing interface for QinQ:
   - `interface FastEthernet0/0`
   - `switchport mode dot1q-tunnel` (if supported) OR use service instance
2. Alternative on 7200 (EFP - Ethernet Flow Point, if supported):
   - `service instance 10 ethernet`
   - `encapsulation dot1q 10`
   - `xconnect 8.8.8.8 600 encapsulation mpls`
3. If neither QinQ nor EFP is supported on your IOS image:
   - Document the concept: customer sends tagged frames, SP adds outer tag (S-VLAN), pseudowire carries double-tagged frame
   - The inner C-VLAN is transparent to the SP
4. **SP model:** customer keeps their VLAN scheme untouched. SP wraps it in a service VLAN.
5. Verify support: `interface Fa0/0` → `service instance ?` — if available, proceed. If not, document as concept.

---

## Section 5: L2VPN Scalability and Design

### Task 13: VPLS Concepts (Multipoint L2VPN)

1. AToM is **point-to-point** (two PEs per pseudowire). What if a customer has 3+ sites needing L2 connectivity?
2. **VPLS** (Virtual Private LAN Service) creates a multipoint L2 domain:
   - Full mesh of pseudowires between all PEs serving the customer
   - Each PE does MAC learning and forwarding (acts like a switch)
3. On R2, R8, R17: attempt to configure VPLS (if supported):
   - `l2 vfi CUSTOMER_A manual`
   - `vpn id 100`
   - `neighbor 8.8.8.8 encapsulation mpls`
   - `neighbor 17.17.17.17 encapsulation mpls`
4. On R8: `l2 vfi CUSTOMER_A manual` → neighbors R2 and R17
5. On R17: `l2 vfi CUSTOMER_A manual` → neighbors R2 and R8
6. Bind VFI to a VLAN interface: `bridge-domain 100`
7. If VPLS is supported: verify all three CEs (R1, R9, R19) can ping each other at L2
8. If not supported on your image: document the concept and the config structure
9. **VPLS vs AToM:** AToM = point-to-point wire. VPLS = multipoint LAN. Both use pseudowires.

### Task 14: Hierarchical VPLS (H-VPLS) Concept

1. Full-mesh VPLS with N PEs = N*(N-1)/2 pseudowires (same scaling problem as iBGP)
2. H-VPLS solution: hub PE (one per region) connects to all spoke PEs
   - Spokes only have one pseudowire (to the hub)
   - Hub has pseudowires to all other hubs (full mesh only between hubs)
3. Design on paper for your topology:
   - Hub 1: R2 (serves R1, R12)
   - Hub 2: R8 (serves R9, R11)
   - Hub 3: R17 (serves R19)
   - Only 3 full-mesh pseudowires between hubs (instead of 10+ in full mesh)
4. If configurable: implement and verify
5. If not: document the design and explain why it scales better
6. **Note:** In modern networks, EVPN is replacing VPLS (better multi-homing, MAC mobility). This is your EVE-NG/SR lab material.

---

## CCIE+ Challenges

### Challenge 1: AToM with FRR — Sub-50ms L2VPN Protection

1. Pseudowire on R2 bound to Tunnel20 (preferred-path)
2. Tunnel20 has FRR enabled with backup tunnel on transit router
3. Start continuous ping from R1 to R9 (10000 packets, timeout 1)
4. Kill a link in Tunnel20's primary path
5. Measure: packet loss should be 0-1 (FRR protects the TE tunnel carrying the pseudowire)
6. The pseudowire itself never goes DOWN — it rides the FRR-protected tunnel
7. **Full stack:** L2VPN → TE tunnel → FRR backup. Three layers, sub-50ms recovery.

### Challenge 2: Pseudowire Load Balancing (Fat Pseudowire)

1. Problem: a single pseudowire is one flow in the core — P routers can't ECMP-balance it
2. Solution: flow-aware transport (FAT PW) — adds a flow label so P routers can load-balance
3. In pseudowire-class: `load-balance flow-label both` (if supported)
4. Verify: `show mpls l2transport vc 100 detail` — flow label enabled
5. On P routers with ECMP: different customer flows within the same pseudowire now take different core paths
6. If not supported on your image: document the concept
7. **Why it matters:** one 10G pseudowire carrying thousands of customer flows — without FAT PW, all 10G goes on one core link. With FAT PW, it spreads across parallel core links.

### Challenge 3: L2VPN + L3VPN Integration — Same Customer, Both Services

1. Customer A wants:
   - L2 service between R1 and R9 (for their own routing, they run OSPF internally)
   - L3 service for internet access (PE routes for them)
2. On R2/R8: configure both simultaneously for Customer A:
   - VLAN 10: xconnect (L2VPN — customer's internal OSPF runs across this)
   - VLAN 20: VRF Customer_A with eBGP (L3VPN — PE provides routing + internet)
3. R1 uses VLAN 10 to talk directly to R9 (L2, their own routing)
4. R1 uses VLAN 20 to get internet via R2 (L3, PE provides default route)
5. Verify: both services work simultaneously
6. Verify: L2VPN traffic and L3VPN traffic take different label stacks in the core
7. **This is the "Swiss Army Knife" SP offering:** multiple service types on one access port

### Challenge 4: Pseudowire Switching (Multi-Segment PW)

1. **Scenario:** R2 needs a pseudowire to R18, but they're far apart — cross multiple provider domains
2. Create a multi-segment pseudowire with R7 as the switching point:
   - Segment 1: R2 ↔ R7 (VC 100)
   - Segment 2: R7 ↔ R18 (VC 100)
   - R7 switches between the two segments (stitches them together)
3. On R7: configure pseudowire switching:
   - `interface pseudowire 1` → xconnect to R2
   - `interface pseudowire 2` → xconnect to R18
   - Connect them: `l2 vfi` or `connect PW-SWITCH pseudowire 1 pseudowire 2`
4. Verify: traffic from R1 reaches R20 across both segments
5. `show mpls l2transport vc` on R7 — shows both segments, switching between them
6. **Use case:** inter-AS L2VPN, or splitting long pseudowires into manageable segments with independent OAM per segment

### Challenge 5: Full Service Provider L2VPN Portfolio

1. Build the complete L2VPN service set simultaneously on your MPLS core:
   - **EPL** (port-mode pseudowire): R1 ↔ R9, dedicated wire
   - **EVPL** (VLAN-mode pseudowire): R12 VLAN 10 ↔ R11 VLAN 10, plus R12 VLAN 20 ↔ R11 VLAN 20
   - **Pseudowire with TE tunnel**: R19 ↔ R20 bound to specific TE path
   - **Protected pseudowire**: one circuit with backup PW for redundancy
2. Verify all services working simultaneously
3. Verify complete isolation between all services (different VC IDs, no cross-talk)
4. Kill various links — verify each service's protection mechanism activates correctly
5. `show mpls l2transport vc` — full dashboard of all L2VPN circuits in your network
6. **Congratulations:** you now have a production-grade SP L2VPN network

---

## Final Validation

By the end of this lab, your network has:

- [ ] Pseudowire bound to TE tunnel (preferred-path) with verified traffic pinning
- [ ] LDP fallback when TE tunnel fails (pseudowire survives on LDP path)
- [ ] Disable-fallback mode tested (pseudowire fails with tunnel — strict path control)
- [ ] Separate voice and data pseudowires on independent TE tunnels
- [ ] Fault isolation proven (one tunnel failure doesn't affect the other pseudowire)
- [ ] Backup pseudowire with automatic failover to redundant PE
- [ ] Three-layer protection stack (FRR + tunnel failover + backup PW) understood
- [ ] VLAN ID rewrite (different VLANs at each end, SP handles translation)
- [ ] Port mode vs VLAN mode understood and configured
- [ ] VPLS concept understood (multipoint L2VPN, if configurable on your image)
- [ ] (CCIE+) FRR protecting TE tunnel carrying pseudowire (sub-50ms L2VPN recovery)
- [ ] (CCIE+) L2VPN + L3VPN coexisting for same customer on same access port
- [ ] (CCIE+) Multi-segment pseudowire switching at intermediate PE
- [ ] (CCIE+) Full SP L2VPN portfolio running simultaneously
