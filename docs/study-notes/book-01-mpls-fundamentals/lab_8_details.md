# Lab 8: BGP Design — Workbook

**Platform:** GNS3 Local (Cisco 7200)
**Prerequisite:** Labs 2 and 3 complete (L3VPN and TE working)

---

## Task 1: Full-Mesh iBGP Problem

1. Currently R2, R8, R17, R18 are all PEs — how many iBGP sessions exist? (N*(N-1)/2)
2. Verify: `show ip bgp vpnv4 all summary` on each PE — count the neighbors
3. If you added 6 more PEs, how many sessions would you need? (that's why full-mesh doesn't scale)
4. Document the current full-mesh topology

---

## Task 2: Implement Route Reflectors

1. Designate R3 as Route Reflector #1
2. Designate R7 as Route Reflector #2 (redundancy)
3. On R3: configure all PEs as RR clients:
   - `neighbor <PE-loopback> route-reflector-client` under address-family vpnv4
4. On R7: same configuration — all PEs as RR clients
5. On all PEs (R2, R8, R17, R18): remove direct iBGP sessions to other PEs
6. On all PEs: configure iBGP sessions to R3 and R7 only
7. Verify: `show ip bgp vpnv4 all summary` — PEs only peer with RRs now
8. Verify: R9 can still ping R1 (vpnv4 routes reflected via RRs)
9. Verify: all VPN routes still present in all PE VRF tables

---

## Task 3: Route Reflector Redundancy

1. Shut R3's BGP process: `neighbor <all> shutdown` or shut R3's loopback
2. Verify: all PEs still have vpnv4 routes via R7 (second RR takes over)
3. Verify: R9 can still ping R1 — no connectivity loss
4. Bring R3 back — verify it re-learns all routes
5. Verify: both RRs have identical vpnv4 tables

---

## Task 4: RR Cluster-ID

1. On both R3 and R7: configure `bgp cluster-id 1` (same cluster)
2. Verify: CLUSTER_LIST attribute appears on reflected routes
3. On R2: `show ip bgp vpnv4 all 9.9.9.9` — look for CLUSTER_LIST and ORIGINATOR_ID
4. Verify: cluster-list prevents routing loops between R3 and R7
5. What happens if you set different cluster-ids on R3 and R7? (try it — routes get reflected twice)

---

## Task 5: BGP Communities for Traffic Policy

1. On R1 (CE): tag routes with community 64512:100 when advertising to R2
   - Use a route-map on R1: `set community 64512:100`
2. On R8 (remote PE): create a policy that sets local-pref 200 for routes with community 64512:100
3. Verify: R8 prefers routes from R1 (via R2) over other paths because of higher local-pref
4. Verify: `show ip bgp vpnv4 vrf Customer_A` — check local-pref on R1's routes
5. Remove the community — verify local-pref returns to default (100)

---

## Task 6: AS-PATH Manipulation for Failover

1. Setup: R1 multi-homed to R2 and R17 (from Lab 6 Task 3)
2. On R1: prepend AS-PATH toward R17 (make it less preferred):
   - Route-map: `set as-path prepend 65001 65001 65001`
3. Verify: R9 prefers path via R2 (shorter AS-PATH)
4. Check on R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — compare paths
5. Shut R1's link to R2
6. Verify: R9 now uses path via R17 (longer AS-PATH but only option)
7. Bring link back — verify traffic returns to R2 path

---

## Task 7: MED (Multi-Exit Discriminator)

1. R1 advertises its loopback 1.1.1.1 to R2 with MED 100
2. R1 advertises same loopback to R17 with MED 200
3. On R8: verify it prefers path via R2 (lower MED = better)
4. Change MED values — swap them
5. Verify: R8 now prefers path via R17
6. Note: MED only compared between paths from the same AS

---

## Task 8: BGP Weight (Local Preference Override)

1. On R8: set weight 500 for routes received from R2: `neighbor <R2> weight 500`
2. Set weight 100 for routes from R17
3. Verify: R8 always prefers routes via R2 regardless of AS-PATH or MED
4. Weight is highest priority in BGP best-path selection (Cisco-specific)
5. Remove weight — verify normal selection resumes

---

## Task 9: Prefix Filtering

1. R1 advertises three loopbacks (1.1.1.1, 11.11.11.11, 111.111.111.111)
2. On R2: create a prefix-list that denies 111.111.111.111/32
3. Apply inbound on the PE-CE session toward R1
4. Verify: R9 can ping 1.1.1.1 and 11.11.11.11 but CANNOT ping 111.111.111.111
5. Verify: `show ip bgp vpnv4 vrf Customer_A` — 111.111.111.111 is missing
6. Remove the filter — verify route reappears

---

## Task 10: BGP Graceful Restart

1. Enable on R2: `bgp graceful-restart` under router bgp
2. Enable on R8: same
3. Verify: `show ip bgp neighbors <peer> | include Graceful`
4. On R2: `clear ip bgp 8.8.8.8` — session resets
5. During restart: verify R8 retains R2's routes for the restart timer duration
6. Verify: R9 can still ping R1 DURING the restart (stale routes used)
7. After session re-establishes: routes refresh and stale routes removed

---

## Task 11: Maximum Prefix Limit

1. On R2 (PE): configure max-prefix limit for R1's session:
   - `neighbor 192.168.12.1 maximum-prefix 5 warning-only`
2. Make R1 advertise more than 5 prefixes (add extra loopbacks)
3. Verify: R2 logs a warning but keeps the session up (warning-only)
4. Change to: `neighbor 192.168.12.1 maximum-prefix 5` (without warning-only)
5. Make R1 advertise > 5 prefixes again
6. Verify: R2 tears down the session — CE is cut off
7. Verify: `show ip bgp vpnv4 vrf Customer_A summary` — session shows as idle/prefix-limit

---

## Validation Checklist

- [ ] Route Reflectors replace full-mesh iBGP
- [ ] RR redundancy: one RR down, VPN still works
- [ ] Cluster-ID prevents reflection loops
- [ ] Communities influence path selection on remote PE
- [ ] AS-PATH prepend creates primary/backup preference
- [ ] MED influences path selection for same-AS routes
- [ ] Weight overrides all other BGP attributes
- [ ] Prefix filtering blocks specific routes
- [ ] Graceful restart prevents traffic loss during BGP reset
- [ ] Max-prefix protects PE from CE route explosion

---

## CCIE+ Challenge Tasks

### Challenge 1: Hierarchical Route Reflectors
- Tier 1 RR: R3 (top-level, knows everything)
- Tier 2 RRs: R6, R7 (each serves a subset of PEs)
- R6 serves R2, R17 | R7 serves R8, R18
- R6 and R7 peer with R3 (tier 1) as clients
- Verify: routes propagate from any PE to any other PE through the hierarchy
- Verify: shut R6 — R2 and R17 lose vpnv4 routes (no alternate path to tier 1)
- Fix: add R7 as backup for R6's clients — verify redundancy

### Challenge 2: RT-Constrained Route Distribution (RFC 4684)
- Enable RT-constraint on all RR-to-PE sessions
- Each PE only advertises its locally configured RTs to the RR
- RR only reflects vpnv4 routes to PEs that have matching import RTs
- Verify: R17 (Customer_D only) does NOT receive Customer_A, B, or E routes
- Measure: reduction in vpnv4 table size on PEs that don't need all routes

### Challenge 3: BGP Add-Path
- R1 is multi-homed to R2 and R17
- Normally, RR only reflects BEST path to other PEs
- Enable add-path on RR: `neighbor <PE> additional-paths send receive`
- Verify: R8 now sees BOTH paths to R1 (via R2 and via R17)
- Verify: R8 can make its own best-path decision with full visibility
- Benefit: faster convergence, no hidden alternate paths

### Challenge 4: BGP Optimal Route Reflection (ORR)
- Without ORR: RR selects best path based on ITS OWN IGP distance to next-hop
- This can be suboptimal for clients who are closer to a different next-hop
- Enable ORR: RR calculates best path FROM EACH CLIENT'S perspective
- Configure: `bgp optimal-route-reflection <group-name>`
- Verify: different clients may receive different best paths from the same RR
- Proves: eliminates suboptimal routing caused by RR location

### Challenge 5: BGP Confederations (Alternative to RR)
- Remove Route Reflectors
- Split AS 64512 into sub-ASes: 65100 (R2, R3, R4) and 65200 (R5, R6, R7, R8)
- Configure confederation: `bgp confederation identifier 64512`
- Configure sub-AS peers: `bgp confederation peers 65200` on 65100 members
- Verify: vpnv4 routes flow between sub-ASes
- Verify: CEs still see AS 64512 (confederation is invisible externally)
- Compare with RR: what are the tradeoffs?

### Challenge 6: BGP Convergence Optimization
- Enable all convergence features simultaneously:
  - `bgp nexthop trigger-delay critical 0 non-critical 500`
  - `bgp bestpath igp-metric ignore` (for certain scenarios)
  - BFD between PEs and RRs
  - `neighbor <peer> fall-over bfd`
- Measure convergence: time from link failure to last PE installing alternate route
- Target: < 1 second end-to-end BGP convergence
- Break a link, timestamp when ping fails and when it recovers
