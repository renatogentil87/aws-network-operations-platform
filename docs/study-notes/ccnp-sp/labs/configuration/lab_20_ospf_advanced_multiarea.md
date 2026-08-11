# Lab 20: OSPF Advanced — Multi-Area SP Design — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — same physical topology, OSPF reconfigured as multi-area
**Prerequisite:** Lab 1 complete (single-area OSPF + LDP running)

**End Goal:** A production-like multi-area OSPF design with area 0 backbone, stub/NSSA areas, inter-area summarization, virtual-links for partitioned backbones, full MD5/SHA authentication on all adjacencies, and sub-second convergence tuning. By the end, you understand how Tier-1 SPs design OSPF for thousands of routers across multiple regions.

---

## Topology Adaptation

Modify the existing single area-0 topology into multi-area:

```
Area 0 (Backbone): R3, R4, R5, R6, R7 (north core P routers)
Area 1 (Region South): R13, R14, R15, R16 (south P routers)
Area 0 PEs (backbone-attached): R2, R8
Area 1 PEs: R17, R18

ABRs (Area 0 ↔ Area 1): R6 and R7
  - R6: Fa4/0 toward R13 in Area 1, all other interfaces in Area 0
  - R7: Fa4/0 toward R14 in Area 1, all other interfaces in Area 0
```

CEs remain unchanged (not in OSPF). MPLS LDP stays enabled on all core interfaces.

---

## Section 1: Multi-Area Foundation

### Task 1: Convert to Multi-Area OSPF

1. On R13, R14, R15, R16, R17, R18: move ALL their interfaces from area 0 to area 1
2. On R6: move Fa4/0 (toward R13) to area 1, keep all others in area 0 — R6 becomes an ABR
3. On R7: move Fa4/0 (toward R14) to area 1, keep all others in area 0 — R7 becomes an ABR
4. Verify: `show ip ospf` on R6 — should show "Area 0" and "Area 1" both active
5. Verify: `show ip ospf` on R7 — same (two areas)
6. Verify: `show ip ospf neighbor` on R13 — neighbors should be in area 1
7. Verify: R2 can still ping R17 (17.17.17.17) — inter-area routing works
8. Verify: `show ip route ospf` on R2 — R17/R18 loopbacks appear as O IA (inter-area)
9. Verify: `show ip ospf database` on R6 — shows Router LSAs for area 0 AND area 1, plus Summary LSAs (Type 3) it generates

### Task 2: Verify Inter-Area Route Propagation

1. On R2: `show ip route 17.17.17.17` — should show O IA with next-hop toward R6 or R7
2. On R17: `show ip route 2.2.2.2` — should show O IA with next-hop toward R13
3. On R6: `show ip ospf database summary` — verify Type 3 LSAs are being generated for area 1 prefixes
4. Count: how many Type 3 LSAs does R6 generate into area 0? (One per area 1 prefix)
5. Count: how many Type 3 LSAs does R6 generate into area 1? (One per area 0 prefix)
6. This demonstrates the "LSA filtering" benefit of multi-area — area 1 routers don't see area 0's Type 1/2 LSAs

### Task 3: MPLS and LDP Still Work Across Areas

1. Verify: `show mpls ldp neighbor` on R6 — LDP sessions to both area 0 and area 1 neighbors
2. Verify: `show mpls forwarding-table 17.17.17.17 32` on R2 — label path exists across areas
3. Verify: `ping mpls ipv4 17.17.17.17/32` from R2 — LSP healthy across area boundary
4. Verify: L3VPN still works — R1 can ping R9 (vpnv4 routes reflected, labels valid)
5. Key insight: MPLS/LDP doesn't care about OSPF areas — it just needs IGP reachability

---

## Section 2: Inter-Area Summarization

### Task 4: Summarize Area 1 Prefixes at ABRs

1. Area 1 loopbacks: 13.13.13.13, 14.14.14.14, 15.15.15.15, 16.16.16.16, 17.17.17.17, 18.18.18.18
2. On R6 (ABR): configure `area 1 range 13.0.0.0 255.0.0.0` — summarizes all area 1 loopbacks into area 0
3. On R7 (ABR): configure same summary
4. Verify: `show ip route ospf` on R2 — should see ONE summary route (13.0.0.0/8) instead of 6 individual /32s
5. Verify: `show ip ospf database summary` on R3 — fewer Type 3 LSAs from R6/R7
6. Test: can R2 still ping 17.17.17.17? (Yes — summary covers it)
7. Test: can R2 still ping 14.14.14.14? (Yes — within the summary range)

### Task 5: Summarize Area 0 Prefixes into Area 1

1. On R6: configure `area 0 range 2.0.0.0 255.0.0.0` — summarizes area 0 loopbacks (2-8) into area 1
2. On R7: configure same
3. Verify: `show ip route ospf` on R17 — should see summary instead of individual /32s for R2-R8
4. Benefit: area 1 routing table is smaller, SPF runs faster on R13-R18
5. Verify: `show ip ospf database summary` on R17 — fewer Type 3 LSAs

### Task 6: Verify Summarization Doesn't Break MPLS

1. Key question: does summarization affect LDP label binding?
2. `show mpls ldp bindings 2.2.2.2 32` on R17 — does a label exist for the specific /32?
3. Answer: YES — LDP binds labels to IGP prefixes. If summarization removes the /32 from the routing table on R17, the LDP label disappears and VPN traffic breaks!
4. Fix: use `area 1 range` carefully — do NOT summarize PE loopbacks that are BGP next-hops
5. Remove the area 0 summary, or make it more specific to exclude PE loopbacks
6. Alternative: advertise PE loopbacks as /32 in ADDITION to the summary (using `not-advertise` selectively)
7. This is a critical SP design lesson — summarization + MPLS requires careful planning

---

## Section 3: Stub and NSSA Areas

### Task 7: Configure Area 1 as a Stub Area

1. On ALL routers in area 1 (R13, R14, R15, R16, R17, R18) AND the ABRs (R6, R7): `area 1 stub`
2. Verify: `show ip ospf` on R13 — shows "Area 1, Stub area"
3. Verify: `show ip route ospf` on R17 — external routes (O E1/E2) disappear, replaced by default route
4. Verify: `show ip ospf database` on R17 — no Type 5 LSAs (external), only Type 3 (summaries) + default
5. Verify: R17 still has a default route (O*IA) pointing to the ABR
6. Verify: R17 can still reach everything (via default route through ABR)
7. Benefit: smaller LSDB and routing table on area 1 routers

### Task 8: Totally Stubby Area

1. On ABRs only (R6, R7): change to `area 1 stub no-summary`
2. Verify: `show ip route ospf` on R17 — now even Type 3 summaries disappear! Only default route remains
3. Verify: `show ip ospf database` on R17 — minimal LSDB (only Type 1/2 for area 1 + one Type 3 default)
4. Verify: R17 can still reach R2 (2.2.2.2) via default route
5. This is the most aggressive LSDB reduction — used for remote/stub sites

### Task 9: NSSA (Not So Stubby Area)

1. Remove stub configuration from area 1
2. Simulate an external route: on R17, redistribute a static route into OSPF (`redistribute static subnets`)
3. Configure a static route on R17: `ip route 100.100.100.0 255.255.255.0 Null0`
4. Verify: `show ip route ospf` on R2 — should see 100.100.100.0/24 as O E2 (external)
5. Now convert area 1 to NSSA: on ALL area 1 routers + ABRs: `area 1 nssa`
6. Verify: `show ip ospf database nssa-external` on R13 — R17's external route appears as Type 7 LSA
7. Verify: `show ip route ospf` on R2 — route now appears as O N2 (NSSA external, converted to Type 5 at ABR)
8. Key difference: NSSA allows external routes from WITHIN the area (via Type 7) but still blocks external Type 5s from outside

---

## Section 4: Authentication

### Task 10: OSPF MD5 Authentication

1. On the R6↔R13 link (inter-area ABR link): enable MD5 authentication
   - R6: `ip ospf authentication message-digest` + `ip ospf message-digest-key 1 md5 SECRETKEY`
   - R13: same configuration
2. Verify: adjacency reforms (may flap briefly during config)
3. Verify: `show ip ospf interface Fa4/0` on R6 — shows "Message digest authentication enabled"
4. Test: change the key on R13 to a WRONG value — adjacency drops
5. Fix: restore correct key — adjacency reforms
6. Extend: apply MD5 auth to ALL core links in area 0

### Task 11: Per-Area Authentication

1. Configure area-level authentication: `area 0 authentication message-digest` under `router ospf 1`
2. This requires ALL interfaces in area 0 to have MD5 keys configured
3. Configure keys on all area 0 interfaces
4. Verify: all area 0 adjacencies remain FULL
5. Configure `area 1 authentication message-digest` — same for area 1
6. Verify: complete OSPF network authenticated end-to-end
7. This is the production SP approach — area-level auth ensures no new router joins without credentials

### Task 12: Key Rollover (Hitless Key Change)

1. On R6 and R13: add a SECOND key: `ip ospf message-digest-key 2 md5 NEWKEY`
2. Verify: adjacency stays UP — OSPF accepts both keys during transition
3. On R6: remove old key 1: `no ip ospf message-digest-key 1 md5 SECRETKEY`
4. Verify: adjacency stays UP (R13 still sends with key 1, but accepts key 2)
5. On R13: remove old key 1
6. Verify: both sides now use key 2 only — hitless migration complete
7. This is how SPs rotate authentication keys without outage

---

## Section 5: Convergence Tuning

### Task 13: SPF Throttle Timers

1. Default SPF: initial 5000ms, second 10000ms, max 10000ms — too slow for SP
2. On all routers: `timers throttle spf 50 200 5000` (50ms initial, 200ms second, 5s max)
3. Verify: `show ip ospf` — SPF throttle timers updated
4. Flap a link — observe: `show ip ospf statistics` — SPF runs within 50ms of detection
5. Compare: what was the convergence time before vs after?

### Task 14: LSA Throttle Timers

1. On all routers: `timers throttle lsa all 50 200 5000`
2. This controls how fast a router RE-ORIGINATES an LSA after a topology change
3. Verify: `show ip ospf` — LSA throttle updated
4. Combined with BFD (from Lab 7): detection in 300ms + SPF in 50ms + LSA in 50ms = sub-second convergence

### Task 15: Interface-Level Timers

1. On all core links: `ip ospf dead-interval minimal hello-multiplier 4`
2. This sets dead-interval to 1 second with hellos every 250ms
3. Verify: `show ip ospf interface` — Hello 250ms, Dead 1s
4. Benefit: 1-second failure detection without BFD (good for platforms without BFD support)
5. Trade-off: more CPU for hello processing on high-density routers
6. SP recommendation: use BFD (Lab 7) instead of aggressive hellos in production

---

## Section 6: Virtual Links

### Task 16: Partitioned Backbone — Virtual Link

1. Scenario: Remove R7 from area 0 backbone (move R7's interfaces to area 1) — now area 0 is partitioned
2. R2/R3/R4/R5/R6 are in area 0; R7 is now in area 1 only
3. Result: R8 (connected to R7) loses area 0 connectivity
4. Fix: configure a virtual-link from R6 to R7 through area 1:
   - R6: `area 1 virtual-link 7.7.7.7`
   - R7: `area 1 virtual-link 6.6.6.6`
5. Verify: `show ip ospf virtual-links` — state FULL
6. Verify: R8 now has area 0 routes again (via virtual-link through area 1)
7. Verify: `show ip ospf` on R7 — shows area 0 membership via virtual-link
8. Revert: move R7 back to area 0, remove virtual-links (restore original multi-area design)

---

## Section 7: Prefix Suppression

### Task 17: Hide Transit Links from Routing Table

1. On all core interfaces: `ip ospf prefix-suppression`
2. Verify: `show ip route ospf | count /30` on R2 — transit /30 routes disappear
3. Verify: `show ip route ospf | count /32` on R2 — loopbacks still present
4. Verify: ALL loopbacks still reachable (ping 3.3.3.3, 4.4.4.4, etc.)
5. Verify: LDP still works — labels still allocated for loopbacks
6. Benefit: 40-50% smaller routing table (no transit links), faster convergence
7. SP production standard: always suppress transit links, only advertise loopbacks
8. Caution: do NOT suppress on the Loopback0 interface itself!

---

## CCIE+ Challenges

### Challenge 1: OSPF Sham-Link for PE-CE OSPF (revisit from Lab 2)

1. With multi-area in place, configure OSPF PE-CE on R8↔R9
2. Add a backdoor link between R1 and R9 (same subnet, same OSPF process)
3. Configure sham-link between R2 and R8 using VRF loopbacks
4. Prove: sham-link makes MPLS path preferred over backdoor
5. Prove: if MPLS fails, traffic falls back to backdoor

### Challenge 2: OSPF Database Filter (LSA Filtering at ABR)

1. On R6 (ABR): configure `area 1 filter-list prefix BLOCK-SPECIFIC in`
2. Block a specific area 0 prefix from entering area 1 (e.g., R4's loopback)
3. Verify: R17 cannot reach R4's loopback, but can reach all others
4. Use case: security — hide specific infrastructure from a customer-facing area

### Challenge 3: OSPF Demand Circuit

1. On a link between R15 and R16: `ip ospf demand-circuit`
2. Verify: OSPF stops sending periodic hellos on that link (hello suppressed)
3. Verify: adjacency stays UP (no dead-timer expiry)
4. Benefit: saves bandwidth on expensive WAN links (satellite, ISDN)
5. Trade-off: slower failure detection (relies on link-down detection, not hello timeout)

### Challenge 4: Max-Metric (Stub Router Advertisement)

1. On R5: `max-metric router-lsa`
2. Verify: `show ip ospf database router 5.5.5.5` — all links advertised with metric 65535
3. Result: no transit traffic flows through R5 (all paths avoid it)
4. Use case: graceful maintenance — drain traffic before shutting down a router
5. On R5: `max-metric router-lsa on-startup 300` — advertise max-metric for 5 minutes after boot
6. Use case: prevent traffic from using a router until it's fully converged (BGP, LDP, TE)

### Challenge 5: OSPF Graceful Shutdown

1. On R5: `router ospf 1` → `shutdown`
2. Observe: R5 advertises max-metric first, then tears down adjacencies
3. Result: traffic gracefully moves away from R5 before it disappears
4. Bring R5 back: `no shutdown` under `router ospf 1`
5. Observe: R5 readvertises normal metrics, traffic returns

---

## Final Validation

By the end of this lab, your network has:

- [ ] Multi-area OSPF (Area 0 backbone + Area 1 region)
- [ ] Two ABRs (R6, R7) connecting the areas
- [ ] Inter-area summarization reducing LSA/route count
- [ ] Stub/NSSA area behavior understood and tested
- [ ] MD5 authentication on all OSPF adjacencies with hitless key rollover
- [ ] Sub-second convergence with SPF/LSA throttle tuning
- [ ] Virtual-link repairing a partitioned backbone
- [ ] Prefix suppression hiding transit /30s
- [ ] (CCIE+) Sham-link, LSA filtering, demand circuit, max-metric, graceful shutdown
