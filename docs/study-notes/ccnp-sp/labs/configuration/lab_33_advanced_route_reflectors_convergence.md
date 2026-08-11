# Lab 33: Advanced Route Reflectors & BGP Convergence — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 26 routers — Topology E (multi-ASN from Lab 32)
**Prerequisite:** Lab 32 complete (transit + peering sessions active, full-table distributed via RRs)

**End Goal:** Redesign the Route Reflector infrastructure for a large-scale SP. Implement hierarchical RR clusters, BGP Add-Path for path diversity, BGP PIC (Prefix Independent Convergence) for sub-second failover, best-external advertisement, optimal RR placement strategies, and RR-induced suboptimal routing fixes. By the end, you can design a RR topology that scales to 1000+ PE routers without suboptimal routing or single points of failure — which is what CCIE-SP expects.

---

## Section 1: Current RR Design — Limitations Analysis

### Task 1: Document Current RR State

1. Current design:
   - R3 (RR-North): reflects to R2, R10, R11, R12, R4-R6
   - R7 (RR-South): reflects to R8, R13-R18
   - Both RRs are P routers (in the forwarding path)
   - Single RR per cluster = single point of failure

2. Identify problems:
   ```
   ! On R2: how many BGP paths does it see for 100.64.1.0/24?
   show ip bgp 100.64.1.0/24
   ! Answer: only 1 (the best path from RR). Even if R10 AND R11 both have paths,
   ! RR sends only the best → R2 loses path diversity
   ```

3. Document the three RR problems for large SPs:
   - **Path hiding:** RR selects best path, clients only see one
   - **Suboptimal routing:** RR picks path based on its OWN IGP metric, which may differ from client's
   - **Single point of failure:** one RR down = all clients lose routes (until reconvergence to backup RR)

### Task 2: Measure Current Convergence Time

1. Simulate transit failure — shut R10's link to R21 (Cogent):
   ```
   ! On R21:
   interface Serial0/0
    shutdown
   ```

2. Time how long R2 takes to switch from Cogent path to Lumen path:
   ```
   ! On R2 — watch for route change:
   debug ip bgp updates 100.64.1.0
   ! Or:
   show ip bgp 100.64.1.0/24
   ! Note: convergence = BGP scanner interval (default 60s!) + RR processing + propagation
   ```

3. Default BGP convergence for iBGP update:
   - R10 detects eBGP down (hold-time 180s default, or fast with BFD)
   - R10 withdraws from R3 (RR)
   - R3 runs best-path, selects R11's path as new best
   - R3 sends UPDATE to all clients
   - **Total:** could be 3-4 minutes with default timers!

---

## Section 2: Hierarchical Route Reflectors

### Task 3: Design Two-Level RR Hierarchy

1. New design:
   ```
   Level 1 (Top-tier RRs): R3, R7 — cluster-id 1
     - Peer with each other (iBGP, non-client)
     - Peer with all Level 2 RRs as clients
     
   Level 2 (Regional RRs): R4 (North), R15 (South) — own cluster-ids
     - R4 cluster-id 4: clients = R2, R10, R11, R12
     - R15 cluster-id 15: clients = R8, R17, R18
     - R4 and R15 are clients of Level 1 RRs
   ```

2. Diagram:
   ```
   Level 1:   R3 (RR) ←────────────→ R7 (RR)
              │  (cluster-id 1)          │  (cluster-id 1)
              │                          │
   Level 2:  R4 (Regional RR)       R15 (Regional RR)
              │  (cluster-id 4)          │  (cluster-id 15)
              ├── R2 (PE)                ├── R8 (PE)
              ├── R10 (ASBR)             ├── R17 (PE)
              ├── R11 (ASBR)             └── R18 (PE)
              └── R12 (ASBR)
   ```

3. Why hierarchical?
   - Level 1 RRs handle inter-regional route distribution
   - Level 2 RRs handle intra-regional route distribution
   - Failure of one Level 2 RR affects only that region
   - Scales to 100s of PEs per Level 2 RR

### Task 4: Configure Level 2 RR — R4 (North Regional)

1. On R4 — become a route reflector:
   ```
   router bgp 64512
    bgp cluster-id 4
    !
    ! Level 1 RRs (R4 is their client):
    neighbor 3.3.3.3 remote-as 64512
    neighbor 3.3.3.3 update-source Loopback0
    neighbor 7.7.7.7 remote-as 64512
    neighbor 7.7.7.7 update-source Loopback0
    !
    ! Local clients:
    neighbor 2.2.2.2 remote-as 64512
    neighbor 2.2.2.2 update-source Loopback0
    neighbor 10.10.10.10 remote-as 64512
    neighbor 10.10.10.10 update-source Loopback0
    neighbor 11.11.11.11 remote-as 64512
    neighbor 11.11.11.11 update-source Loopback0
    neighbor 12.12.12.12 remote-as 64512
    neighbor 12.12.12.12 update-source Loopback0
    !
    address-family ipv4 unicast
     neighbor 3.3.3.3 activate
     neighbor 7.7.7.7 activate
     neighbor 2.2.2.2 activate
     neighbor 2.2.2.2 route-reflector-client
     neighbor 10.10.10.10 activate
     neighbor 10.10.10.10 route-reflector-client
     neighbor 11.11.11.11 activate
     neighbor 11.11.11.11 route-reflector-client
     neighbor 12.12.12.12 activate
     neighbor 12.12.12.12 route-reflector-client
    exit-address-family
   ```

2. On R3 (Level 1 RR) — update to peer with R4 as client:
   ```
   router bgp 64512
    bgp cluster-id 1
    !
    address-family ipv4 unicast
     ! R4 is now a client (Level 2 RR):
     neighbor 4.4.4.4 activate
     neighbor 4.4.4.4 route-reflector-client
     ! R7 is a non-client peer (Level 1):
     neighbor 7.7.7.7 activate
     ! Remove direct client relationships with PEs (they now go through R4):
     no neighbor 2.2.2.2 route-reflector-client
     no neighbor 10.10.10.10 route-reflector-client
    exit-address-family
   ```

### Task 5: Configure Level 2 RR — R15 (South Regional)

1. On R15:
   ```
   router bgp 64512
    bgp cluster-id 15
    !
    neighbor 3.3.3.3 remote-as 64512
    neighbor 3.3.3.3 update-source Loopback0
    neighbor 7.7.7.7 remote-as 64512
    neighbor 7.7.7.7 update-source Loopback0
    !
    neighbor 8.8.8.8 remote-as 64512
    neighbor 8.8.8.8 update-source Loopback0
    neighbor 17.17.17.17 remote-as 64512
    neighbor 17.17.17.17 update-source Loopback0
    neighbor 18.18.18.18 remote-as 64512
    neighbor 18.18.18.18 update-source Loopback0
    !
    address-family ipv4 unicast
     neighbor 3.3.3.3 activate
     neighbor 7.7.7.7 activate
     neighbor 8.8.8.8 activate
     neighbor 8.8.8.8 route-reflector-client
     neighbor 17.17.17.17 activate
     neighbor 17.17.17.17 route-reflector-client
     neighbor 18.18.18.18 activate
     neighbor 18.18.18.18 route-reflector-client
    exit-address-family
   ```

### Task 6: Verify Hierarchical RR Operation

1. Route propagation path:
   ```
   ! R10 learns route from Cogent → sends to R4 (Level 2 RR)
   ! R4 reflects to R2, R11, R12 (intra-region) AND to R3 (Level 1)
   ! R3 reflects to R7 (Level 1 peer)
   ! R7 reflects to R15 (Level 2 South)
   ! R15 reflects to R8, R17, R18
   
   ! Verify on R8:
   show ip bgp 100.64.1.0/24
   ! ORIGINATOR_ID should be R10 (10.10.10.10)
   ! CLUSTER_LIST should contain: 4, 1, 15 (traversed Level 2 North → Level 1 → Level 2 South)
   ```

2. Check cluster-list for loop prevention:
   ```
   show ip bgp 100.64.1.0/24 detail
   ! cluster list: 4 1 15
   ! This prevents routing loops — if R15 sees its own cluster-id (15), it drops the route
   ```

---

## Section 3: BGP Add-Path — Solving Path Hiding

### Task 7: Understand the Path Hiding Problem

1. Setup: R10 learns route X via Cogent (AS-path: 174), R11 learns route X via Lumen (AS-path: 3356)
2. Both send to R4 (Level 2 RR)
3. R4 selects BEST (say Cogent, shorter IGP to R10) → reflects ONLY the Cogent path to R2
4. Problem: if R2's IGP metric to R11 is BETTER than to R10, R2 would prefer the Lumen path — but it never sees it!

5. Verify path hiding:
   ```
   ! On R4 (RR):
   show ip bgp 100.64.1.0/24
   ! Should see 2 paths (from R10 and R11), with one marked as best
   
   ! On R2 (client):
   show ip bgp 100.64.1.0/24
   ! Only sees 1 path! The one R4 chose as best.
   ```

### Task 8: Enable BGP Add-Path

1. On R4 (Level 2 RR) — advertise multiple paths to clients:
   ```
   router bgp 64512
    address-family ipv4 unicast
     bgp additional-paths select all
     bgp additional-paths send receive
     neighbor 2.2.2.2 advertise additional-paths all
     neighbor 10.10.10.10 advertise additional-paths all
     neighbor 11.11.11.11 advertise additional-paths all
     neighbor 12.12.12.12 advertise additional-paths all
    exit-address-family
   ```

2. On clients (R2, R10, R11, R12) — enable receiving additional paths:
   ```
   router bgp 64512
    address-family ipv4 unicast
     bgp additional-paths receive
    exit-address-family
   ```

3. **Critical:** requires `clear ip bgp * soft` to activate (capabilities are negotiated at session establishment).

### Task 9: Verify Add-Path

1. On R2 — should now see MULTIPLE paths:
   ```
   show ip bgp 100.64.1.0/24
   ! Now shows 2+ paths! Both Cogent (via R10) and Lumen (via R11)
   ! R2 can select the one optimal for ITS OWN IGP metric to the next-hop
   ```

2. Check path-id in the BGP table:
   ```
   show ip bgp 100.64.1.0/24
   ! Each path has a unique path-id (1, 2, etc.)
   ! Best path is still marked with '>' but alternatives are available
   ```

3. Benefit: if R10 goes down, R2 already has the backup path in its table — convergence is INSTANT (no waiting for RR to send new best).

---

## Section 4: BGP Prefix Independent Convergence (PIC)

### Task 10: Understand BGP PIC

1. **Without PIC:** when next-hop becomes unreachable, router must:
   - Walk through ALL prefixes using that next-hop
   - For each prefix, recalculate best path
   - Update FIB for each prefix
   - With 500K prefixes via one next-hop → seconds of convergence

2. **With PIC:** router pre-programs backup next-hop in FIB:
   - When primary next-hop fails, ALL prefixes using it switch to backup simultaneously
   - Single FIB update operation regardless of prefix count
   - Sub-second convergence (similar to FRR for MPLS)

3. Two components:
   - **PIC Edge:** fast convergence for PE-CE link failures (VPN routes)
   - **PIC Core:** fast convergence for core link failures (IGP reconvergence triggers BGP update)

### Task 11: Configure BGP PIC

1. Enable PIC on R2 (PE with multiple exit points):
   ```
   router bgp 64512
    address-family ipv4 unicast
     bgp additional-paths install
     bgp bestpath prefix-sid-map
    exit-address-family
   ```

   **Note:** `bgp additional-paths install` is the key — it installs the backup path in CEF/FIB before it's needed.

2. Alternative (IOS 15.x syntax — may vary):
   ```
   router bgp 64512
    address-family ipv4 unicast
     bgp recursion host
    exit-address-family
   
   ! CEF:
   cef table output-chain build favor convergence-speed
   ```

3. For VPNv4 (PIC Edge):
   ```
   router bgp 64512
    address-family vpnv4 unicast
     bgp additional-paths install
    exit-address-family
   ```

### Task 12: Test PIC Convergence

1. Ensure Add-Path is working (R2 has 2 paths for 100.64.1.0/24):
   ```
   show ip bgp 100.64.1.0/24
   ! Path 1: via R10 (next-hop 10.10.10.10) — best
   ! Path 2: via R11 (next-hop 11.11.11.11) — backup, installed via PIC
   ```

2. Check CEF for backup path:
   ```
   show ip cef 100.64.1.0/24 detail
   ! Should show: primary next-hop AND repair/backup next-hop
   ```

3. Simulate failure — shut R10's link:
   ```
   ! On R10:
   interface FastEthernet0/0
    shutdown
   
   ! Immediately check on R2:
   show ip cef 100.64.1.0/24
   ! Should ALREADY be using backup path — no waiting for BGP update!
   ```

4. Measure convergence:
   - Without PIC: wait for BGP scanner (60s) + best-path recalculation + FIB update = 60-180s
   - With PIC: detect next-hop failure (via IGP/BFD) + FIB swap = sub-second to <5s

---

## Section 5: Best-External Advertisement

### Task 13: Understand Best-External

1. **Problem:** when a RR client is also an ASBR (like R10, R11), it learns external routes. It selects a best eBGP path. But the RR only reflects that ONE best path. Other ASBRs never see the alternative exit points.

2. **Best-External:** the ASBR advertises its best EXTERNAL path to iBGP peers, even if the iBGP best path (from another ASBR) is overall best. This gives the RR visibility into all available exit points.

3. Configuration on ASBRs (R10, R11, R12):
   ```
   router bgp 64512
    address-family ipv4 unicast
     bgp advertise-best-external
    exit-address-family
   ```

4. Effect: R10 will advertise its Cogent-learned paths to R4 (RR) even if R10's own best path for some prefix is via iBGP (from R11/R12). This feeds path diversity into the RR system.

### Task 14: Verify Best-External

1. Check R4 receives paths from both R10 and R11 for the same prefix:
   ```
   ! On R4:
   show ip bgp 100.64.1.0/24
   ! Should see:
   !   Path from R10 (next-hop 10.10.10.10, AS-path: 174)
   !   Path from R11 (next-hop 11.11.11.11, AS-path: 3356)
   !   Path from R12 (next-hop 12.12.12.12, AS-path: via IXP/peer)
   ```

2. Combined with Add-Path: RR has multiple paths AND advertises them all to clients → maximum path diversity.

---

## Section 6: Optimal RR Placement

### Task 15: RR Placement Strategy Analysis

1. **Option 1: RR on P routers (current design — R3, R7)**
   - **Pro:** P routers are in the forwarding path anyway, RR failure = IGP reconvergence handles it
   - **Pro:** close to clients physically (low latency for iBGP updates)
   - **Con:** RR's IGP metric to exit points may not match client's metric → suboptimal selection

2. **Option 2: Dedicated RR (out-of-band, not in data path)**
   - **Pro:** RR failure doesn't affect forwarding at all (no transit traffic through RR)
   - **Pro:** can be over-provisioned for memory (holds full table + all paths)
   - **Con:** additional hardware cost, latency for updates
   - **Real world:** many Tier-1s use dedicated RR VMs (e.g., on x86 running BIRD/GoBGP)

3. **Option 3: RR on PE routers**
   - **Pro:** client-specific — RR knows exact IGP costs from that PE's perspective
   - **Con:** PE already busy with VPN processing, memory-constrained
   - **Rarely used in production**

4. **Recommendation for CCIE-SP answer:** P routers with diverse placement (one per region), with Add-Path to mitigate suboptimal selection. For Internet BGP specifically, dedicated RRs are increasingly common.

### Task 16: Fix Suboptimal Routing Without Add-Path

1. Alternative to Add-Path — **IGP cost community (not standard, Cisco-specific):**
   ```
   ! On RR R4 — set the IGP metric into an extended community:
   route-map SET-IGP-COST permit 10
    set extcommunity cost igp pre-bestpath
   ```

2. Alternative — **Diverse-path (advertise best + next-best):**
   ```
   router bgp 64512
    address-family ipv4 unicast
     bgp bestpath compare-routerid
     maximum-paths ibgp 2
    exit-address-family
   ```

3. **Correct answer for CCIE:** Use Add-Path (Section 3) — it's the standardized solution (RFC 7911).

---

## Section 7: BGP Convergence Tuning

### Task 17: Fast eBGP Session Detection

1. Use BFD on eBGP sessions for sub-second failure detection:
   ```
   ! On R10 (toward Cogent R21):
   interface FastEthernet0/0
    bfd interval 300 min_rx 300 multiplier 3
   
   router bgp 64512
    neighbor 198.51.100.2 fall-over bfd
   ```

2. Without BFD: failure detection = BGP hold time (default 180s). With BFD: ~900ms.

### Task 18: BGP Timer Tuning

1. Reduce keepalive/holdtime for iBGP sessions to RRs:
   ```
   router bgp 64512
    ! Faster iBGP:
    neighbor 3.3.3.3 timers 10 30
    neighbor 7.7.7.7 timers 10 30
    ! Keepalive every 10s, hold 30s → detect failure in 30s
   ```

2. For eBGP transit sessions — use aggressive timers:
   ```
   neighbor 198.51.100.2 timers 3 9
   ! Keepalive 3s, hold 9s — detect in 9s without BFD
   ```

3. BGP scanner interval (affects how fast best-path is recalculated):
   ```
   router bgp 64512
    bgp scan-time 5
    ! Default is 60s. Reduce to 5s for faster convergence.
    ! Trade-off: more CPU usage on the RR
   ```

### Task 19: Next-Hop Tracking (NHT)

1. Enable fast next-hop tracking — detect IGP changes affecting BGP next-hops immediately:
   ```
   router bgp 64512
    bgp nexthop trigger enable
    bgp nexthop trigger delay 5
    ! React to IGP changes affecting next-hops within 5 seconds
   ```

2. Verify:
   ```
   show ip bgp nexthop
   ! Shows all next-hops and their reachability status
   ! Critical: if a next-hop becomes unreachable, BGP should react in seconds, not minutes
   ```

---

## CCIE+ Challenges

### Challenge 1: Three-Level RR Hierarchy

Add a THIRD level of RR for massive scale:
- Level 1: R3, R7 (global RRs)
- Level 2: R4, R15 (regional RRs)
- Level 3: R5, R6, R14, R16 (POP-level RRs, each serving 2-3 PEs)

Configure and verify. Document: when would a 3-level hierarchy be needed? (Answer: 10,000+ PE routers, e.g., China Telecom or Deutsche Telekom)

### Challenge 2: RR Cluster Redundancy

Make R4 AND R5 both Level 2 RRs for the North region with the SAME cluster-id:
```
! R4:
bgp cluster-id 4
! R5:
bgp cluster-id 4
```
- Verify: clients (R2, R10, R11, R12) peer with BOTH R4 and R5
- Verify: if R4 dies, R5 continues reflecting without route loss
- Verify: cluster-list prevents loops (both R4 and R5 have cluster-id 4)

### Challenge 3: Measure and Compare Convergence

Create a systematic test:
1. Baseline: no Add-Path, no PIC, default timers → measure convergence
2. Add BFD on eBGP → re-measure
3. Add Add-Path → re-measure
4. Add PIC → re-measure
5. Enable bgp scan-time 5 → re-measure

Use continuous ping from R1 (CE) to a destination behind R21 (Cogent). Count dropped packets during failover. Document each improvement.

### Challenge 4: Solve RR Suboptimal Routing Without Add-Path

Scenario: R2's shortest IGP path to R11 is 10, to R10 is 50. But R4 (RR) has IGP 5 to R10 and 30 to R11. R4 selects R10's path as best → reflects to R2 → R2 is forced to use R10 (suboptimal from R2's perspective).

Fix this WITHOUT Add-Path. Options:
- Multiple RRs per region with different placement
- IGP metric manipulation
- Change RR client membership
- Document pros/cons of each approach

### Challenge 5: Virtual RR Using Linux + BIRD

Design (conceptual):
- Deploy a Linux VM (GoBGP or BIRD) as a dedicated RR
- Peers with all PEs via iBGP
- Not in the forwarding path
- Can run on a server with 128GB RAM → holds millions of routes
- Document: config for BIRD as a BGP RR (pseudo-config, IOS equivalent shown)

This is how hyperscalers (Google, AWS, Meta) run their BGP infrastructure — worthwhile understanding.

---

## Troubleshooting Checklist

| Symptom | Check | Common Fix |
|---|---|---|
| Route missing after hierarchy change | `show ip bgp` on each RR level | Check cluster-id, route-reflector-client on correct neighbors |
| Route loops (route bouncing) | `show ip bgp <prefix>` — check CLUSTER_LIST | Cluster-ids must be unique per cluster |
| Add-Path not working | `show ip bgp neighbors X.X.X.X capabilities` | Both sides must negotiate add-path; `clear ip bgp * soft` |
| PIC not engaging backup | `show ip cef <prefix> detail` | Verify backup path installed (`bgp additional-paths install`) |
| Suboptimal routing persists with Add-Path | Client still picking RR's best? | Verify client receives multiple paths (`show ip bgp <prefix>`) |
| iBGP session flapping | High keepalive frequency + congested link | Increase timers or fix congestion |
| Best-external not advertised | `show ip bgp <prefix>` on ASBR | Verify `bgp advertise-best-external` under correct AF |

---

## Key Commands Reference

```
! RR verification:
show ip bgp summary
show ip bgp <prefix> [detail]
show ip bgp update-group
show ip bgp cluster-id
show ip bgp neighbors [addr] [capabilities]

! Add-Path:
show ip bgp <prefix> — look for path-id
show ip bgp neighbors <addr> capabilities
show ip bgp additional-paths

! PIC:
show ip cef <prefix> detail — look for repair/backup path
show ip cef switching-state

! Convergence:
show ip bgp nexthop
show ip bgp rib-failure
debug ip bgp updates
show bfd neighbors [detail]

! Hierarchy:
show ip bgp <prefix> — check ORIGINATOR_ID and CLUSTER_LIST
show ip bgp community
```
