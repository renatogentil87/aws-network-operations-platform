# Lab 10: IS-IS as SP IGP — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers. Replace OSPF with IS-IS on the core.
**Prerequisite:** Lab 1 concepts understood (IGP + LDP fundamentals)

**End Goal:** Migrate the SP core from OSPF to IS-IS — the IGP preferred by most Tier-1 ISPs. By the end, you have IS-IS running with MPLS LDP, TE extensions, multi-level hierarchy, and understand why SPs prefer IS-IS over OSPF for large-scale networks.

---

## Section 1: Basic IS-IS Deployment

### Task 1: Enable IS-IS on the Core

1. On R2: configure IS-IS:
   - `router isis CORE`
   - `net 49.0002.0020.0200.2002.00` (area 49.0002, system-id derived from loopback 2.2.2.2)
   - `is-type level-2-only` (SP core is typically L2-only)
   - `metric-style wide` (required for TE extensions)
   - `passive-interface Loopback0`
2. On R2's core interfaces (Gi1/0 toward R3, Gi2/0 toward R6):
   - `ip router isis CORE`
   - `isis circuit-type level-2-only`
3. Repeat for ALL P and PE routers (R3-R8, R13-R18) with appropriate NET addresses:
   - NET format: 49.0002.XXXX.XXXX.XXXX.00 where X encodes the loopback
   - R3: `net 49.0002.0030.0300.3003.00`
   - R8: `net 49.0002.0080.0800.8008.00`
   - Keep all as `is-type level-2-only` for now
4. Do NOT enable IS-IS on PE-CE interfaces (CEs stay as they are)
5. Verify: `show isis neighbors` on R2 — adjacencies to R3 and R6 should be UP
6. Verify: `show isis database` on R2 — all routers appear in the L2 database
7. Verify: `show ip route isis` on R2 — all loopbacks reachable via IS-IS

### Task 2: Disable OSPF — Cut Over to IS-IS

1. Before removing OSPF: verify IS-IS has full reachability (`ping` all PE loopbacks from R2)
2. On ALL core routers: `no router ospf 1`
3. Verify: `show ip route` — all routes now learned via IS-IS (not OSPF)
4. Verify: `show mpls ldp neighbor` — LDP sessions re-establish over IS-IS paths
5. Verify: VPN still works — R1 can ping R9 (9.9.9.9) via L3VPN
6. If LDP sessions drop temporarily: expected — they'll reconverge once IS-IS provides the routes
7. **Critical check:** all PE loopbacks reachable, all LDP sessions UP, all vpnv4 sessions UP

### Task 3: Verify MPLS LDP Over IS-IS

1. On R2: `show mpls ldp neighbor` — all P router neighbors present
2. On R2: `show mpls forwarding-table` — labels allocated for IS-IS-learned routes
3. From R1: traceroute to R9 (9.9.9.9) — should still show MPLS labels in the core
4. On R3: `show mpls forwarding-table` — transport labels being swapped correctly
5. LDP doesn't care whether the IGP is OSPF or IS-IS — it just needs reachability to loopbacks
6. Verify: `show mpls ldp bindings 8.8.8.8 32` on R2 — label binding exists for R8

---

## Section 2: IS-IS Metrics and Path Control

### Task 4: Wide Metrics and Interface Costs

1. Verify: `show isis database detail R2.00-00` — check metric values (should be wide metrics)
2. Default IS-IS wide metric on interfaces = 10
3. On R2's Gi1/0 (toward R3): `isis metric 100 level-2`
4. On R2's Gi2/0 (toward R6): `isis metric 10 level-2`
5. Verify: `show ip route 8.8.8.8` on R2 — traffic should prefer the path via R6 (lower metric)
6. Traceroute from R2 to R8 — confirm it goes R6→R7→R8 (avoiding R3 due to high metric)
7. Revert R2 Gi1/0 metric to 10 — verify path returns to shortest

### Task 5: Reference Bandwidth (Auto-Cost)

1. On all core routers: `metric-style wide` should already be set
2. Challenge: make metrics reflect interface speed automatically
3. On R2: set reference bandwidth:
   - `router isis CORE`
   - Note: IS-IS doesn't have `auto-cost reference-bandwidth` like OSPF
   - Instead, manually set metrics: GigE = 10, FastEthernet = 100
4. Apply across the core:
   - All GigabitEthernet interfaces: `isis metric 10`
   - All FastEthernet interfaces: `isis metric 100`
5. Verify: `show isis database detail` — metrics reflect interface speeds
6. Verify: traffic prefers GigE paths (lower metric) over FastEthernet paths
7. Traceroute from R2 to R8 — should prefer all-GigE path if one exists

### Task 6: IS-IS Authentication

1. On R2 and R3 (shared link): configure IS-IS authentication:
   - `isis authentication mode md5 level-2`
   - `isis authentication key-chain ISIS-KEY level-2`
   - Create key-chain: `key chain ISIS-KEY` → `key 1` → `key-string CISCO`
2. Apply on BOTH routers' shared interfaces
3. Verify: adjacency stays UP (matching keys)
4. Misconfigure key on R3 — verify adjacency drops
5. Fix key — adjacency restores
6. Deploy authentication on ALL core links (security best practice)
7. Verify: `show isis neighbors` — all adjacencies UP with authentication

---

## Section 3: IS-IS Multi-Level Hierarchy

### Task 7: Split Into Level-1 and Level-2

1. Redesign: core routers (R3-R7) remain Level-2-only
2. Southern sub-topology (R13-R16) becomes Level-1 within area 49.0013
3. R6 and R7 become L1/L2 routers (border between levels):
   - `is-type level-1-2` on R6 and R7
4. On R13, R14, R15, R16: change to Level-1-only:
   - `is-type level-1`
   - Change NET to area 49.0013: `net 49.0013.0130.1301.3013.00` (R13)
5. On R17, R18 (PEs in southern topology): Level-1 in area 49.0013
6. Verify: `show isis neighbors` on R6 — should show L2 neighbors (R3, R5, R2) AND L1 neighbors (R13)
7. Verify: `show isis database level-1` on R13 — only sees L1 routers in area 49.0013
8. Verify: `show isis database level-2` on R3 — sees all L2 routers across all areas
9. Verify: R17 can still reach R2 (route leaked from L2 into L1 by R6/R7)

### Task 8: Route Leaking (L2 to L1)

1. Default behaviour: L1/L2 routers (R6, R7) inject a default route into L1
2. On R13: `show ip route` — should see a default route (or summary) pointing to R6/R7
3. Problem: R17 uses default route to reach R2 — but doesn't know the exact path
4. Enable route leaking for specific prefixes:
   - On R6: `router isis CORE` → `redistribute isis level-2 into level-1 route-map L2-TO-L1`
   - Route-map L2-TO-L1: match PE loopbacks (2.2.2.2, 8.8.8.8) — allow these into L1
5. Verify: R17 now has specific routes to R2 and R8 (not just default)
6. Verify: `show ip route 2.2.2.2` on R17 — learned via IS-IS L1 with proper metric
7. Verify: VPN traffic from R19 still reaches R1 (end-to-end works via leaked routes)

### Task 9: Verify Multi-Level with MPLS

1. Check: LDP sessions from R17 to R2 — still UP? (Need loopback reachability)
2. Check: `show mpls forwarding-table` on R13 — labels for R2's loopback exist
3. From R19: traceroute to R1 (via VPN) — should show MPLS labels through both L1 and L2
4. The key: LDP doesn't care about IS-IS levels — it only needs IP reachability to loopbacks
5. But: if route leaking is not configured properly, LDP sessions to remote loopbacks will fail
6. Verify: `show mpls ldp neighbor` on R17 — sessions to R3/R7 (RRs) still UP

---

## Section 4: IS-IS for MPLS Traffic Engineering

### Task 10: Enable TE Extensions in IS-IS

1. On all core routers: under `router isis CORE`:
   - `mpls traffic-eng router-id Loopback0`
   - `mpls traffic-eng level-2` (advertise TE info in L2 LSPs)
2. On all core interfaces: `mpls traffic-eng tunnels` (if not already from Lab 3)
3. On all core interfaces: `ip rsvp bandwidth` (if not already)
4. Verify: `show isis database detail R2.00-00` — look for TE sub-TLVs:
   - Extended IS Reachability TLV (22) with TE sub-TLVs
   - Traffic Engineering Router ID TLV (134)
5. Compare with OSPF: OSPF uses Type 10 opaque LSAs; IS-IS uses TLV 22 extensions
6. Verify: `show mpls traffic-eng topology` — all routers and links appear (same as with OSPF)

### Task 11: TE Tunnel Over IS-IS

1. Create a TE tunnel from R2 to R8 (same as Lab 3 Task 2):
   - Tunnel0, destination 8.8.8.8, path-option 1 dynamic, autoroute announce
2. Verify: tunnel comes UP — CSPF uses the IS-IS TE topology database
3. Verify: `show mpls traffic-eng tunnels tunnel0` — path computed correctly
4. Traceroute from R2 to R8 — traffic uses the tunnel
5. Create an explicit path — verify it works identically to OSPF-based TE
6. **Key point:** RSVP-TE doesn't care about the IGP. CSPF reads the TE topology database, which is populated by either OSPF or IS-IS. The tunnel behaviour is identical.

### Task 12: IS-IS Overload Bit (Maintenance Mode)

1. On R5: set overload bit: `set-overload-bit`
2. Verify: `show isis database R5.00-00` — overload bit is SET
3. Effect: other routers avoid R5 for transit traffic (treat it as last resort)
4. Verify: traceroute from R2 to R8 — should avoid R5 (find alternate path)
5. Use case: putting a router into maintenance without shutting it down
6. Remove overload bit — verify R5 returns to normal transit duty
7. Timed overload: `set-overload-bit on-startup 120` — overload for 120 seconds after reboot (prevents traffic before IGP converges)
8. **SP practice:** always configure on-startup overload on all routers

---

## Section 5: IS-IS vs OSPF — Operational Comparison

### Task 13: Convergence Comparison

1. With IS-IS running: start continuous ping from R1 to R9
2. Kill a core link (R3→R4) — count packet loss
3. Compare with your Lab 1/3 OSPF experience — is convergence similar?
4. Configure IS-IS fast timers:
   - On interfaces: `isis hello-interval 1` + `isis hello-multiplier 3` (3-second dead time)
   - Under router isis: `spf-interval 5 50 200` (initial=50ms, increment=200ms, max=5s)
   - `prc-interval 5 50 200` (partial route calculation timers)
5. Repeat the link failure test — convergence should be faster
6. Compare: IS-IS SPF and OSPF SPF use the same Dijkstra algorithm — timers are the difference

### Task 14: IS-IS Advantages for SP Scale

1. Document: why do Tier-1 SPs prefer IS-IS?
   - IS-IS runs directly on L2 (not IP-dependent) — survives IP misconfigurations
   - IS-IS extensions don't require new LSA types (just add TLVs) — easier to extend
   - IS-IS multi-level is simpler than OSPF multi-area (no ABR complications)
   - IS-IS has no concept of DR/BDR on broadcast segments (DIS is preemptable)
   - One IS-IS instance handles IPv4 + IPv6 natively (multi-topology)
2. On R2: `show isis protocol` — note multi-topology capability
3. Compare: with OSPF you need OSPFv3 for IPv6. With IS-IS, one process handles both.
4. Count total LSPs: `show isis database | count` — compare complexity with OSPF LSA database

---

## CCIE+ Challenges

### Challenge 1: IS-IS Multi-Topology for IPv6

1. Enable IPv6 on core interfaces (link-local + global addresses)
2. Under `router isis CORE`: enable multi-topology:
   - `address-family ipv6`
   - `multi-topology`
3. On core interfaces: `ipv6 router isis CORE`
4. Verify: `show isis ipv6 rib` — IPv6 routes appear
5. Verify: IPv4 and IPv6 can use DIFFERENT shortest paths (multi-topology independence)
6. This is how SPs run dual-stack without OSPFv3 — single IS-IS process, two topologies

### Challenge 2: IS-IS Prefix Suppression

1. On core links: suppress transit link prefixes from IS-IS:
   - `isis advertise-prefix` removed (or use `isis suppress`)
   - Only advertise loopbacks into IS-IS
2. Verify: `show ip route isis` on R2 — only /32 loopbacks, no transit /30 links
3. Benefit: smaller routing table, faster convergence, transit links not targetable from outside
4. Verify: MPLS still works (LDP only needs loopback reachability — transit IPs unnecessary)
5. **SP best practice:** advertise only loopbacks into IGP. Transit link IPs are operational only.

### Challenge 3: IS-IS + BFD + LFA Stack

1. Deploy the full IS-IS protection stack:
   - BFD on all IS-IS interfaces: `isis bfd`
   - IS-IS fast-reroute: `fast-reroute per-prefix level-2 all` (LFA)
   - Fast hello: `isis hello-interval 1`
2. Kill a core link — measure convergence
3. Target: sub-second convergence with BFD + LFA
4. Compare with OSPF + BFD + LFA from Lab 7 — results should be similar
5. Verify: `show isis fast-reroute` — backup paths pre-computed

### Challenge 4: IS-IS Graceful Restart (IETF)

1. On R2: `graceful-restart` under router isis
2. On R3: same
3. Clear IS-IS adjacency: `clear isis *`
4. During restart: verify R3 retains routes from R2 (stale, forwarding continues)
5. After re-adjacency forms: routes refresh
6. Verify: continuous ping from R1 to R9 survives the IS-IS restart (0-1 packets lost)

### Challenge 5: Migrate Back to OSPF (Reverse Migration)

1. Enable OSPF back on all core routers (alongside IS-IS)
2. Both IGPs running simultaneously — verify both have full topology
3. Cisco AD: OSPF = 110, IS-IS = 115 — OSPF wins by default
4. Traffic should shift to OSPF paths (lower AD)
5. Verify: VPN still works, TE tunnels still work
6. Remove IS-IS — network now runs OSPF again cleanly
7. **Proves:** you can migrate between IGPs in production without downtime (ships-in-the-night)

---

## Final Validation

By the end of this lab, your network has:

- [ ] IS-IS Level-2 running on all core routers (OSPF removed)
- [ ] MPLS LDP fully operational over IS-IS (all PE loopbacks labeled)
- [ ] L3VPN working end-to-end over IS-IS IGP
- [ ] Wide metrics configured reflecting interface speeds
- [ ] IS-IS authentication deployed on all core links
- [ ] Multi-level hierarchy (L1 for southern topology, L2 for core)
- [ ] Route leaking from L2 to L1 providing specific PE reachability
- [ ] TE extensions in IS-IS populating the TE topology database
- [ ] TE tunnels operational over IS-IS (identical behavior to OSPF)
- [ ] Overload bit for maintenance mode understood
- [ ] IS-IS convergence tuned with fast timers
- [ ] (CCIE+) Multi-topology IS-IS for IPv4 + IPv6
- [ ] (CCIE+) Prefix suppression reducing IS-IS table size
- [ ] (CCIE+) Full protection stack (BFD + LFA + fast-reroute)
- [ ] (CCIE+) Graceful restart preserving forwarding during IS-IS restart
- [ ] (CCIE+) IGP migration technique (ships-in-the-night) demonstrated
