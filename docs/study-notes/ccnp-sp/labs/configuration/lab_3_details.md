# Lab 3: MPLS Traffic Engineering — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers. Focus on core RSVP-TE signalling and tunnel operations.
**Prerequisite:** Lab 1 complete (OSPF + LDP running, all loopbacks reachable via MPLS)

**End Goal:** A fully traffic-engineered SP core where PE-to-PE traffic travels over RSVP-TE tunnels with explicit path control, bandwidth admission, link coloring, preemption tiers, and auto-bandwidth. By the end, VPN customer traffic from Lab 2 rides TE tunnels instead of IGP shortest path.

---

## Section 1: Enable the TE Foundation

### Task 1: Activate MPLS TE on All Core Routers

1. Enable `mpls traffic-eng tunnels` globally on all P and PE routers (R2, R3, R4, R5, R6, R7, R8, R13, R14, R15, R16, R17, R18)
2. Under OSPF process 1, add `mpls traffic-eng router-id Loopback0` and `mpls traffic-eng area 0`
3. Enable `mpls traffic-eng tunnels` on every core-facing interface (all P-to-P and PE-to-P links — NOT PE-to-CE links)
4. Enable `ip rsvp bandwidth` on every core-facing interface (use interface bandwidth as the reservable amount)
5. Verify: `show mpls traffic-eng topology` on R2 — all 13 MPLS routers appear with their links and available bandwidth
6. Verify: `show ip rsvp interface` on R3 — every TE-enabled interface is listed with allocatable bandwidth
7. Verify: `show ip ospf database opaque-area` — Type 10 LSAs (TE TLVs) are being flooded

### Task 2: First Dynamic Tunnel — R2 to R8

1. Create Tunnel0 on R2 with destination 8.8.8.8 (R8 loopback)
2. Set `tunnel mode mpls traffic-eng`
3. Set `path-option 1 dynamic`
4. Set `tunnel mpls traffic-eng bandwidth 1000`
5. Configure `tunnel mpls traffic-eng autoroute announce`
6. Set `ip unnumbered Loopback0`
7. Verify: `show mpls traffic-eng tunnels tunnel0` — state is UP
8. Verify: note which path CSPF computed (the explicit route hop list)
9. On R2: `show ip route 8.8.8.8` — next-hop should show Tunnel0
10. Traceroute from R2 to 8.8.8.8 — confirm traffic uses the tunnel path
11. Compare: `show ip route 8.8.8.8` before and after the tunnel — what changed?

### Task 3: Verify the TE Topology Database

1. On R2: `show mpls traffic-eng topology 8.8.8.8` — examine the paths available to R8
2. Identify: how many equal-cost TE paths exist between R2 and R8?
3. On R5: `show mpls traffic-eng link-management bandwidth-allocation` — confirm bandwidth reserved for Tunnel0 on transit interfaces
4. On R3: `show ip rsvp reservation` — find the RSVP reservation for Tunnel0 and note the bandwidth

---

## Section 2: Explicit Path Control

### Task 4: Force Traffic Through a Specific Path

1. Create an IP explicit-path named "VIA-R4":
   - next-address R3 loopback (3.3.3.3)
   - next-address R4 loopback (4.4.4.4)
   - next-address R5 loopback (5.5.5.5)
   - next-address R8 loopback (8.8.8.8)
2. Create Tunnel1 on R2 with destination 8.8.8.8
3. Set `path-option 1 explicit name VIA-R4`
4. Set bandwidth 1000
5. Verify: `show mpls traffic-eng tunnels tunnel1` — state is UP, using the explicit path
6. Traceroute from R2 to 8.8.8.8 via Tunnel1 — confirm hops are R3→R4→R5→R8
7. Compare: is this path different from the CSPF dynamic path of Tunnel0?

### Task 5: Build the Alternate Path

1. Create an IP explicit-path named "VIA-R6":
   - next-address R6 loopback (6.6.6.6)
   - next-address R7 loopback (7.7.7.7)
   - next-address R8 loopback (8.8.8.8)
2. Create Tunnel2 on R2 with destination 8.8.8.8 using explicit path "VIA-R6"
3. Set bandwidth 1000
4. Verify: Tunnel2 is UP and uses R6→R7→R8
5. You now have three tunnels to R8: dynamic (Tunnel0), via-R4 (Tunnel1), via-R6 (Tunnel2)
6. Verify: `show mpls traffic-eng tunnels brief` — all three are UP simultaneously

### Task 6: Primary/Backup Failover

1. Remove Tunnel1 and Tunnel2 (they were for testing)
2. Reconfigure Tunnel0 with TWO path options:
   - `path-option 1 explicit name VIA-R4` (primary)
   - `path-option 2 explicit name VIA-R6` (backup)
3. Verify: Tunnel0 is using path-option 1 (VIA-R4)
4. Start continuous ping from R2 to 8.8.8.8 (repeat 1000)
5. Shut R4's interface toward R5 (Gi1/0, ip 172.16.45.1) — break the primary path
6. Verify: Tunnel0 switches to path-option 2 (VIA-R6)
7. Count dropped packets — note the failover time (typically 2-5 seconds)
8. Bring R4's interface back up
9. On R2: `mpls traffic-eng reoptimize` — force tunnel back to primary
10. Verify: Tunnel0 returns to path-option 1

---

## Section 3: Bandwidth Engineering

### Task 7: Admission Control — Prove It Works

1. Reconfigure Tunnel0 with bandwidth 90000 kbps on explicit path VIA-R4
2. Verify: Tunnel0 is UP, bandwidth reserved on every hop
3. Check: `show ip rsvp interface` on R3, R4, R5 — confirm allocated bandwidth
4. Create Tunnel3 on R2 to R8 with bandwidth 90000 kbps using the SAME path VIA-R4
5. Verify: Tunnel3 FAILS to come up — not enough bandwidth
6. Check: `show mpls traffic-eng tunnels tunnel3` — note the error reason (insufficient bandwidth)
7. Reduce Tunnel3 bandwidth to fit within remaining capacity on the links
8. Verify: Tunnel3 now comes UP and coexists with Tunnel0
9. Verify: `show ip rsvp interface` on R3 — total allocated = Tunnel0 + Tunnel3

### Task 8: Preemption — Priority Wins

1. Set Tunnel0 priority: `tunnel mpls traffic-eng priority 7 7` (setup 7, hold 7 — lowest)
2. Set Tunnel0 bandwidth to 80000
3. Verify: Tunnel0 is UP on path VIA-R4
4. Create Tunnel_Priority on R2 to R8 on the SAME path VIA-R4:
   - Priority 0 0 (highest)
   - Bandwidth 80000
5. Verify: Tunnel_Priority comes UP and preempts Tunnel0
6. Check: `show mpls traffic-eng tunnels tunnel0` — what happened? (Should be down or on backup path)
7. Check: `show ip rsvp reservation` — only Tunnel_Priority holds the reservation
8. Remove Tunnel_Priority — verify Tunnel0 recovers
9. Clean up: reset Tunnel0 to priority 7 7 and bandwidth 1000

---

## Section 4: Link Colouring and Path Constraints

### Task 9: Assign Attribute Flags (Colours)

1. On ALL GigabitEthernet core interfaces: `mpls traffic-eng attribute-flags 0x1` (colour: "high-speed")
2. On ALL FastEthernet core interfaces: `mpls traffic-eng attribute-flags 0x2` (colour: "standard")
3. Verify: `show mpls traffic-eng topology` on R2 — each link shows its attribute-flags
4. Confirm: R2→R3 (Gi1/0) shows 0x1, R3→R4 (Fa0/0) shows 0x2, R3→R6 (Fa3/0) shows 0x2

### Task 10: Tunnels That Follow Colour Rules

1. Create Tunnel_HighSpeed on R2 to R8:
   - `tunnel mpls traffic-eng affinity 0x1 mask 0x1` (REQUIRE high-speed links)
   - path-option 1 dynamic
2. Verify: Tunnel_HighSpeed comes UP using only GigabitEthernet links
3. Check the path: `show mpls traffic-eng tunnels tunnel_highspeed` — all hops are GigE
4. Create Tunnel_Standard on R2 to R8:
   - `tunnel mpls traffic-eng affinity 0x2 mask 0x2` (REQUIRE standard links)
   - path-option 1 dynamic
5. Verify: Tunnel_Standard uses only FastEthernet links (or fails if no all-FE path exists)
6. Create Tunnel_AvoidGigE on R2 to R8:
   - `tunnel mpls traffic-eng affinity 0x0 mask 0x1` (EXCLUDE high-speed links)
   - path-option 1 dynamic
7. Verify: this tunnel avoids all GigabitEthernet links
8. Explore: what happens if no path satisfies the affinity constraint? (Tunnel stays DOWN)

---

## Section 5: Carry VPN Traffic Over TE Tunnels

### Task 11: VPN Traffic Follows the Tunnel

1. Ensure Tunnel0 is UP with `autoroute announce` (from Task 2)
2. Ensure Lab 2 VPN is working: R1 can ping R9 (9.9.9.9) via MPLS L3VPN
3. On R2: `show ip cef vrf Customer_A 9.9.9.9` — verify outgoing interface is Tunnel0
4. From R1: traceroute to 9.9.9.9 — confirm traffic follows Tunnel0's explicit path
5. Verify: the label stack shows TWO labels (top = TE transport, bottom = VPN)
6. Compare: remove autoroute announce from Tunnel0, check CEF again — VPN traffic falls back to LDP path
7. Re-enable autoroute announce — VPN traffic returns to tunnel

### Task 12: Auto-Bandwidth — Tunnel Adapts to VPN Load

1. Configure auto-bandwidth on Tunnel0:
   - `tunnel mpls traffic-eng auto-bw`
   - `max-bw 500000`
   - `min-bw 1000`
   - `bw-limit min 1000 max 500000`
   - `adjustment-threshold 10`
2. Verify: `show mpls traffic-eng tunnels tunnel0 | include auto-bw` — shows auto-bw active
3. From R1: generate traffic — `ping 9.9.9.9 repeat 10000 size 1500 timeout 1`
4. Check: `show mpls traffic-eng tunnels tunnel0` — observe output rate counter increasing
5. Wait for auto-bandwidth collection interval to pass (default 5 min; for lab speed, lower to 1 min with `frequency 60`)
6. Verify: tunnel bandwidth reservation has increased
7. Stop traffic, wait for next interval
8. Verify: bandwidth reservation decreases toward minimum

### Task 13: TE Metric vs IGP Metric — Independence

1. On R3's interface toward R7 (Gi2/0): set `mpls traffic-eng administrative-weight 50000`
2. Keep the OSPF cost unchanged on that same interface
3. Delete and recreate Tunnel0 with `path-option 1 dynamic` — force CSPF recomputation
4. Verify: Tunnel0's dynamic path now AVOIDS R3→R7 (TE weight too expensive)
5. Traceroute from R2 to R8 using the global routing table (not the tunnel) — IGP still uses R3→R7 if it's shortest
6. Proves: TE path computation and IGP forwarding are completely independent
7. Remove the administrative-weight — restore normal TE topology

---

## Section 6: QoS-Aware Tunnel Selection (EXP-Based)

### Task 14: Build Separate Voice and Data Tunnels

1. Remove Tunnel0's autoroute announce (clean slate for this section)
2. Create two explicit-path tunnels from R2 to R8:
   - **Tunnel_Voice** (Tunnel10): explicit path VIA-R4 (R3→R4→R5→R8) — the low-hop path
     - Bandwidth: 50000
     - Priority: 1 1 (high priority — voice gets bandwidth first)
   - **Tunnel_Data** (Tunnel11): explicit path VIA-R6 (R6→R7→R8) — the alternate path
     - Bandwidth: 100000
     - Priority: 7 7 (low priority — data uses remaining capacity)
3. Both tunnels: `ip unnumbered Loopback0`, `tunnel mode mpls traffic-eng`
4. Verify: both tunnels are UP — `show mpls traffic-eng tunnels brief`

### Task 15: Assign EXP Values to Tunnels

1. On Tunnel_Voice (Tunnel10): `tunnel mpls traffic-eng exp 5` (EXP 5 = maps from DSCP EF = voice)
2. On Tunnel_Data (Tunnel11): `tunnel mpls traffic-eng exp 0 1 2 3 4 6 7` (everything else)
3. Enable autoroute on BOTH tunnels: `tunnel mpls traffic-eng autoroute announce`
4. Verify: `show mpls traffic-eng autoroute` — both tunnels participating
5. Verify: `show mpls traffic-eng tunnels tunnel10` — shows "EXP 5"
6. Verify: `show mpls traffic-eng tunnels tunnel11` — shows "EXP 0 1 2 3 4 6 7"

**Note:** If `tunnel mpls traffic-eng exp` is not supported on your IOS 15.2 image, skip to Task 16 (PBR method) which achieves the same result.

### Task 16: Alternative — Policy-Based Routing for Tunnel Selection

If CBTS (EXP-based) is not available, use PBR on R2's CE-facing interface:

1. Create an access-list matching voice traffic:
   - `ip access-list extended VOICE` — match DSCP EF (or specific source/dest for your lab)
   - `ip access-list extended DATA` — match everything else
2. Create a route-map on R2:
   - `route-map STEER-TRAFFIC permit 10` → match VOICE → `set interface Tunnel10`
   - `route-map STEER-TRAFFIC permit 20` → match DATA → `set interface Tunnel11`
3. Apply on R2's VRF CE-facing interface: `ip policy route-map STEER-TRAFFIC` under Fa0/0 (toward R1)
4. Verify: `show ip policy` on R2 — policy applied to Fa0/0

### Task 17: Mark Traffic and Verify Separation

1. On R1: generate voice-like traffic with DSCP EF:
   - `ping 9.9.9.9 tos 184` (TOS 184 = DSCP EF = binary 101110 shifted left by 2)
2. On R1: generate normal data traffic:
   - `ping 9.9.9.9` (default TOS 0 = best effort)
3. On R2: `show interfaces Tunnel10 stats` — voice tunnel should show packets
4. On R2: `show interfaces Tunnel11 stats` — data tunnel should show packets
5. On R5 (transit for voice path): `show interfaces Gi2/0 stats` — confirm voice tunnel traffic transits here
6. On R7 (transit for data path): `show interfaces Fa0/0 stats` — confirm data tunnel traffic transits here
7. Verify: voice and data take DIFFERENT physical paths through the core

### Task 18: Prove Bandwidth Protection

1. Voice tunnel has priority 1 1, data tunnel has priority 7 7
2. If both tunnels compete for the same link (change data tunnel to same path as voice):
   - Voice tunnel holds its bandwidth reservation
   - Data tunnel gets whatever is left
3. Oversubscribe the data path: create a third tunnel with bandwidth exceeding remaining capacity
4. Verify: voice tunnel is NEVER preempted — data tunnel goes down first
5. Revert data tunnel to its own path (VIA-R6) — restore separation
6. **SP model:** voice always gets its guaranteed path; data is best-effort and absorbs congestion

---

## CCIE+ Challenges

### Challenge 1: Fast Reroute (FRR) — Link Protection

1. On Tunnel0 (R2→R8 via VIA-R4): enable FRR — `tunnel mpls traffic-eng fast-reroute`
2. On R3 (first transit router): create a backup tunnel (Tunnel10) that bypasses the R3→R4 link
   - Explicit path: R3→R6→R5→R4 (goes around the R3→R4 link)
   - `tunnel mpls traffic-eng backup-path Tunnel10` is NOT the correct syntax — use `mpls traffic-eng backup-path Tunnel10` under R3's interface Fa0/0 (toward R4)
3. Verify: `show mpls traffic-eng fast-reroute database` on R3 — backup is pre-signalled
4. Start continuous ping from R1 to R9 (10000 packets, timeout 1)
5. Shut R3's Fa0/0 (link toward R4)
6. Count packet loss — target: 0-1 packets (sub-50ms switchover)
7. Compare with Section 2 Task 6 failover time (2-5 seconds) — FRR should be 10-50x faster
8. Bring R3 Fa0/0 back — verify Tunnel0 returns to primary path

### Challenge 2: Node Protection (NNHOP Bypass)

1. Protect against R4 failing entirely (not just the link to R4)
2. On R3: create a backup tunnel that bypasses R4 completely
   - Path must reach R5 (the next-next-hop) without touching R4
   - Example: R3→R6→R5 or R3→R7→R5
3. Enable as NNHOP backup on R3's interface toward R4
4. Verify: `show mpls traffic-eng fast-reroute database` shows "NNHOP" protection type
5. Shut ALL interfaces on R4 (simulate complete node failure)
6. Verify: traffic continues flowing — Tunnel0 uses NNHOP backup around R4
7. Packet loss should still be 0-2 packets

### Challenge 3: DS-TE (DiffServ-Aware TE)

1. Configure two bandwidth pools on core interfaces:
   - `ip rsvp bandwidth <total> sub-pool <premium-amount>`
   - Example: total 100000, sub-pool 30000
2. Create Tunnel_BestEffort: uses global pool bandwidth (default)
3. Create Tunnel_Premium: uses sub-pool — `tunnel mpls traffic-eng bandwidth sub-pool 25000`
4. Verify: both tunnels UP, each reserving from its respective pool
5. Oversubscribe the sub-pool (create another sub-pool tunnel exceeding 30000)
6. Verify: sub-pool tunnel fails, global pool tunnel is unaffected
7. Proves: premium traffic gets guaranteed bandwidth independent of best-effort

### Challenge 4: Load Sharing Across Parallel TE Tunnels

1. Create two tunnels from R2 to R8 with DIFFERENT explicit paths (VIA-R4 and VIA-R6)
2. Both tunnels: `autoroute announce`, same bandwidth
3. On R2: `show ip cef 8.8.8.8 internal` — both tunnels should appear as equal-cost paths
4. From R1, generate traffic to multiple R9 destinations — observe traffic splits across both tunnels
5. Change one tunnel's load-share value: `tunnel mpls traffic-eng load-share 3`
6. Verify: traffic distribution changes (3:1 ratio)
7. Verify: `show mpls traffic-eng autoroute` — both tunnels participating with their load-share values

### Challenge 5: Forwarding Adjacency (Tunnel as an IGP Link)

1. Remove `autoroute announce` from Tunnel0
2. Configure `tunnel mpls traffic-eng forwarding-adjacency` on Tunnel0
3. Verify: Tunnel0 now appears as a link in OSPF — `show ip ospf neighbor` on R2 shows the tunnel
4. On OTHER routers (R3, R6): `show ip route 8.8.8.8` — they now see the tunnel as a path option
5. Difference from autoroute: autoroute only affects the headend; forwarding-adjacency affects ALL routers in the area
6. Traceroute from R6 to R8 — does it use R2's tunnel? (It might, depending on metric)
7. Revert to autoroute announce for normal operation

### Challenge 6: Make-Before-Break Reoptimization

1. Tunnel0 is UP on path VIA-R4
2. While running continuous ping from R1 to R9, change Tunnel0's explicit path to VIA-R6
3. Observe: `show mpls traffic-eng tunnels tunnel0 detail` — look for "Reopt. Info" showing old and new LSP
4. Count packet loss during the path change — should be ZERO (new path signalled before old torn down)
5. Verify: `show mpls traffic-eng tunnels tunnel0` — path is now VIA-R6, no traffic disruption
6. This is make-before-break — the production-safe way to move traffic between paths

### Challenge 7: Inter-Area TE with Loose Hops

1. Split OSPF: Area 0 contains R2, R3, R4, R6. Area 1 contains R5, R7, R8. R3 and R6 are ABRs.
2. Attempt to build a TE tunnel from R2 to R8 — observe: standard RSVP-TE fails (no TE topology visibility across areas)
3. Configure loose-hop explicit path:
   - `next-address loose 3.3.3.3` (ABR — expand within area 0)
   - `next-address loose 8.8.8.8` (destination — expand within area 1)
4. Verify: tunnel comes UP — each area computes its own segment
5. Verify: `show mpls traffic-eng tunnels tunnel0` — path shows expanded hops in both areas
6. Revert OSPF to single area 0 when done

---

## Final Validation

By the end of this lab, your network has:

- [ ] RSVP-TE enabled on all 13 core routers with OSPF TE extensions flooding
- [ ] Dynamic tunnel (CSPF-computed path) operational between R2 and R8
- [ ] Explicit-path tunnels with full hop-by-hop control
- [ ] Primary/backup path failover working (2-5 second convergence)
- [ ] Bandwidth admission control rejecting over-subscribed tunnels
- [ ] Preemption: high-priority tunnels displace low-priority tunnels
- [ ] Link colouring (affinity bits) constraining tunnel paths to specific link types
- [ ] VPN customer traffic (R1→R9) riding the TE tunnel via autoroute
- [ ] Auto-bandwidth dynamically adjusting reservation based on traffic load
- [ ] TE metric and IGP metric operating independently (proven)
- [ ] Separate voice and data TE tunnels with different paths
- [ ] EXP-based or PBR-based tunnel selection steering traffic by class
- [ ] Voice traffic protected by higher priority (cannot be preempted by data)
- [ ] (CCIE+) FRR link protection with sub-50ms failover
- [ ] (CCIE+) Node protection (NNHOP bypass) surviving complete router failure
- [ ] (CCIE+) DS-TE with separate bandwidth pools for premium vs best-effort
- [ ] (CCIE+) Load sharing across parallel TE tunnels with configurable ratio
- [ ] (CCIE+) Forwarding adjacency exposing tunnels to the IGP
- [ ] (CCIE+) Make-before-break achieving zero packet loss during path changes
- [ ] (CCIE+) Inter-area TE using loose-hop expansion at ABRs
