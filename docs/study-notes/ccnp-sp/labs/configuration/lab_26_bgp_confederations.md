# Lab 26: BGP Confederations — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 2 RRs, 6 CEs. Full L3VPN operational.
**Prerequisite:** Labs 2 and 8 complete (RRs on R3/R7, all VPNs working, BGP path control understood)

**End Goal:** Replace the Route Reflector design with BGP Confederations — splitting AS 64512 into two sub-ASes (64512.1 for the north, 64512.2 for the south). Confederation eBGP peers connect the sub-ASes while preserving iBGP attributes like LOCAL_PREF and MED. By the end, you understand when confederations outperform RRs, how to migrate between the two, and the tradeoffs involved.

---

## Section 1: Confederation Architecture and Planning

### Task 1: Plan the Sub-AS Split

1. Document the current topology split:
   - **Sub-AS 64512.1 (North):** R2 (PE), R3 (P/former RR), R4, R5, R6 — 5 routers
   - **Sub-AS 64512.2 (South):** R7 (P/former RR), R8 (PE), R13, R14, R15, R16, R17 (PE), R18 (PE) — 8 routers
2. Identify confederation eBGP peers (inter-sub-AS links):
   - R5 ↔ R7 (north-south interconnect)
   - R6 ↔ R13 (backup north-south interconnect)
3. Within each sub-AS: full iBGP mesh (or sub-AS RR — explored later)
4. External CEs (R1, R9, R11, R12, R19, R20) continue using real eBGP — they see AS 64512 unchanged
5. **Key principle:** confederation sub-AS numbers are NEVER visible outside AS 64512

### Task 2: Remove Route Reflector Configuration

1. On R3: remove all `neighbor X.X.X.X route-reflector-client` statements
2. On R7: remove all `neighbor X.X.X.X route-reflector-client` statements
3. Verify: `show ip bgp vpnv4 all summary` — sessions still up but routes may drop (expected during migration)
4. On all PEs: verify vpnv4 sessions lose reflected routes — connectivity will break temporarily
5. **Document:** note which routes disappear — this confirms RR was the distribution mechanism

### Task 3: Configure Confederation Identifier on All Routers

1. On ALL routers in AS 64512 (R2-R8, R13-R18):
   ```
   router bgp <sub-AS-number>
    bgp confederation identifier 64512
   ```
   - North routers (R2, R3, R4, R5, R6): `router bgp 65501`
   - South routers (R7, R8, R13, R14, R15, R16, R17, R18): `router bgp 65502`
2. **Critical:** change `router bgp 64512` to `router bgp 65501` (north) or `router bgp 65502` (south)
3. This requires removing and recreating the BGP process — plan for outage
4. Verify: `show ip bgp summary` — local AS shows sub-AS number (65501 or 65502)
5. Verify: `show ip bgp confederation identifier` — displays 64512 as the confederation ID

---

## Section 2: Intra-Sub-AS iBGP Mesh

### Task 4: Full iBGP Mesh Within Sub-AS 65501 (North)

1. On R2: configure iBGP sessions to R3, R4, R5, R6 (all within sub-AS 65501):
   ```
   router bgp 65501
    bgp confederation identifier 64512
    bgp confederation peers 65502
    neighbor 3.3.3.3 remote-as 65501
    neighbor 3.3.3.3 update-source Loopback0
    neighbor 3.3.3.3 next-hop-self
    address-family vpnv4
     neighbor 3.3.3.3 activate
     neighbor 3.3.3.3 send-community both
   ```
2. Repeat for all pairs within sub-AS 65501 (R2↔R3, R2↔R4, R2↔R5, R2↔R6, R3↔R4, R3↔R5, R3↔R6, R4↔R5, R4↔R6, R5↔R6)
3. Verify: `show ip bgp vpnv4 all summary` on R2 — all north neighbors in Established state
4. Verify: `show ip bgp vpnv4 vrf Customer_A` on R2 — local VRF routes present
5. **Count:** 5 routers × (5-1)/2 = 10 iBGP sessions within the north sub-AS

### Task 5: Full iBGP Mesh Within Sub-AS 65502 (South)

1. On R8: configure iBGP sessions to R7, R13, R14, R15, R16, R17, R18:
   ```
   router bgp 65502
    bgp confederation identifier 64512
    bgp confederation peers 65501
    neighbor 7.7.7.7 remote-as 65502
    neighbor 7.7.7.7 update-source Loopback0
    neighbor 7.7.7.7 next-hop-self
    address-family vpnv4
     neighbor 7.7.7.7 activate
     neighbor 7.7.7.7 send-community both
   ```
2. Repeat for ALL pairs within sub-AS 65502 (8 routers = 28 iBGP sessions)
3. Verify: `show ip bgp vpnv4 all summary` on R8 — all south neighbors in Established state
4. Verify: `show ip bgp vpnv4 all summary` on R17 — sessions to R7, R8, R13-R16, R18
5. **Observation:** 28 sessions in the south sub-AS — this is the iBGP full-mesh scaling problem that confederations merely subdivide (not eliminate)

---

## Section 3: Confederation eBGP Between Sub-ASes

### Task 6: Configure Confederation eBGP Peers

1. On R5 (north, sub-AS 65501) toward R7 (south, sub-AS 65502):
   ```
   router bgp 65501
    neighbor 7.7.7.7 remote-as 65502
    neighbor 7.7.7.7 update-source Loopback0
    neighbor 7.7.7.7 ebgp-multihop 5
    address-family vpnv4
     neighbor 7.7.7.7 activate
     neighbor 7.7.7.7 send-community both
     neighbor 7.7.7.7 next-hop-unchanged
   ```
2. On R7 (south) toward R5 (north):
   ```
   router bgp 65502
    neighbor 5.5.5.5 remote-as 65501
    neighbor 5.5.5.5 update-source Loopback0
    neighbor 5.5.5.5 ebgp-multihop 5
    address-family vpnv4
     neighbor 5.5.5.5 activate
     neighbor 5.5.5.5 send-community both
     neighbor 5.5.5.5 next-hop-unchanged
   ```
3. Repeat for backup link: R6 (north) ↔ R13 (south)
4. Verify: `show ip bgp vpnv4 all summary` on R5 — R7 session shows Established
5. Verify: `show ip bgp vpnv4 all neighbors 7.7.7.7` — "Member of BGP confederation"
6. **Key:** confederation eBGP uses eBGP mechanics (TTL, loop prevention) but preserves iBGP attributes

### Task 7: Verify Attribute Preservation Across Confederation

1. On R2: set LOCAL_PREF 200 on a route from R1 (CE):
   ```
   route-map SET-HIGH-LP permit 10
    set local-preference 200
   neighbor 192.168.12.1 route-map SET-HIGH-LP in
   ```
2. On R2: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — local-pref 200
3. On R5: `show ip bgp vpnv4 all 1.1.1.1` — local-pref 200 (iBGP within north sub-AS)
4. On R7: `show ip bgp vpnv4 all 1.1.1.1` — **local-pref 200 PRESERVED** (confederation eBGP)
5. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — local-pref 200 (iBGP within south sub-AS)
6. **Contrast with real eBGP:** true eBGP strips LOCAL_PREF. Confederation eBGP preserves it.
7. Verify MED similarly: set MED 50 on R2, confirm it arrives at R8 with MED 50

### Task 8: Verify AS-PATH Appearance

1. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — examine AS-PATH
2. Expected AS-PATH: `(65501) 65001`
   - `(65501)` = confederation segment (in parentheses) — sub-AS the route traversed
   - `65001` = real external AS (R1's AS)
3. On R1 (CE): `show ip bgp` — check AS-PATH for routes from R8's customers
4. Expected: AS-PATH shows only `64512` — confederation internals HIDDEN from external peers
5. **Critical verification:** CEs and external peers must NEVER see sub-AS numbers
6. On R12 (CE, AS 65012): verify routes from R1 show AS-PATH `64512 65001` — no sub-AS leaked
7. Verify: `show ip bgp vpnv4 all 1.1.1.1` on R17 — AS-PATH `(65501) 65001` (confederation path visible internally)

---

## Section 4: LOCAL_PREF and MED Across Confederation

### Task 9: LOCAL_PREF for Traffic Engineering Across Sub-ASes

1. On R2: set LOCAL_PREF 300 for R1's loopback 1.1.1.1/32:
   ```
   route-map LP-300 permit 10
    match ip address prefix-list R1-LOOPBACK
    set local-preference 300
   route-map LP-300 permit 20
   ```
2. On R8: also receives R9's route (same AS 65001) — R9's routes have default local-pref 100
3. On R17: `show ip bgp vpnv4 vrf Customer_A` — if both R1 (via R2, local-pref 300) and R9 (via R8, local-pref 100) advertise same prefix → local-pref 300 wins → traffic exits via R2
4. Change LOCAL_PREF on R2 to 50 → traffic shifts to R8 exit
5. **SP use case:** confederation preserves LOCAL_PREF across sub-ASes, enabling AS-wide traffic engineering
6. Verify: traceroute from R19 to R1's loopback — follows the higher LOCAL_PREF path

### Task 10: MED Handling Within Confederation

1. On R1 (CE): advertise two prefixes with different MEDs:
   - 1.1.1.1/32 → MED 100
   - 11.11.11.11/32 → MED 200
2. On R2: verify MEDs received: `show ip bgp vpnv4 vrf Customer_A`
3. On R8: verify MEDs preserved across confederation boundary:
   - `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — MED 100
   - `show ip bgp vpnv4 vrf Customer_A 11.11.11.11` — MED 200
4. **Key:** MED comparison rules still apply — only compared between routes from same neighboring AS
5. Configure `bgp always-compare-med` on R8 — now MED compared across all paths
6. Verify: best-path selection changes when MED comparison is enabled globally
7. Remove `bgp always-compare-med` — return to default (MED only compared within same AS)

### Task 11: Confederation and IGP Cost to Next-Hop

1. On R17: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — note IGP cost to BGP next-hop
2. If LOCAL_PREF and AS-PATH are equal: IGP metric to next-hop breaks the tie
3. Modify OSPF/IS-IS cost on R17's path toward R2 vs toward R8
4. Verify: best-path shifts based on IGP cost (hot-potato routing)
5. **Confederation interaction:** since next-hop is preserved (next-hop-unchanged), each PE calculates its own IGP distance
6. Compare: without `next-hop-unchanged` on confederation eBGP peers — next-hop changes to the confederation border router
7. Document: which behavior is preferred for optimal routing? (Answer: next-hop-unchanged for true hot-potato)

---

## Section 5: Comparison with Route Reflectors

### Task 12: Document RR vs Confederation Tradeoffs

1. **Scalability:**
   - RR: 2 RRs serve all PEs — O(N) sessions per RR, O(1) per PE
   - Confederation: full mesh within sub-AS — if sub-AS has M routers → O(M²/2) sessions
   - RR wins at scale unless you also use RRs within sub-ASes
2. **Optimal routing:**
   - RR: reflects SINGLE best path (from RR's perspective) → suboptimal for some PEs
   - Confederation: eBGP between sub-ASes carries all attributes → each sub-AS picks independently
   - Confederation can produce better path selection
3. **Configuration complexity:**
   - RR: add `route-reflector-client` on 2 routers — simple
   - Confederation: change AS numbers on every router, maintain mesh — complex
4. **Failure domain:**
   - RR: RR failure affects all clients (mitigated by redundant RRs)
   - Confederation: sub-AS failure only affects that sub-AS (inter-sub-AS link loss is critical)
5. Verify operational difference: remove one confederation eBGP link (R5↔R7)
6. Check: does R2 still reach R8? (Yes, via backup R6↔R13)
7. Remove BOTH confederation eBGP links — north and south fully partitioned

### Task 13: Confederation with RR Hybrid (Sub-AS RR)

1. Within sub-AS 65502 (8 routers): full mesh = 28 sessions — still too many
2. Deploy R7 as RR within sub-AS 65502:
   ```
   router bgp 65502
    neighbor 8.8.8.8 route-reflector-client
    neighbor 17.17.17.17 route-reflector-client
    neighbor 18.18.18.18 route-reflector-client
   ```
3. Remove the full iBGP mesh within south sub-AS — PEs only peer with R7
4. Verify: routes still flow from R8 to R17 via R7 (sub-AS RR)
5. Verify: routes cross confederation boundary R7→R5 to reach north sub-AS
6. **Best of both worlds:** confederation for inter-region, RR for intra-region
7. Count sessions: R7 has 7 client sessions + 1 confederation eBGP = 8 total (vs 28 full mesh)

---

## Section 6: Migration from RR to Confederation

### Task 14: Plan the Migration Sequence

1. **Migration approach:** parallel operation during transition
   - Step 1: Keep RR operational
   - Step 2: Configure confederation parameters (bgp confederation identifier)
   - Step 3: Establish confederation eBGP peers alongside RR
   - Step 4: Verify routes available via both mechanisms
   - Step 5: Remove RR config
   - Step 6: Remove stale iBGP sessions
2. **Risk:** changing `router bgp` AS number requires process restart — causes outage
3. **Mitigation:** perform sub-AS at a time:
   - Migrate north (R2, R3, R4, R5, R6) first while south still uses RR
   - Then migrate south
4. Document: expected downtime per router during BGP process change

### Task 15: Execute Migration (North First)

1. On R2: save current BGP config to notepad — you'll need to recreate it
2. On R2: `no router bgp 64512` — removes entire BGP process (OUTAGE BEGINS for R2)
3. On R2: configure new BGP process:
   ```
   router bgp 65501
    bgp confederation identifier 64512
    bgp confederation peers 65502
    ! Recreate all neighbor statements, VRFs, address-families
   ```
4. Repeat for R3, R4, R5, R6
5. Verify: intra-north iBGP mesh established
6. Configure R5→R7 confederation eBGP (R7 still in AS 64512 with old config)
7. **Problem:** R7 sees R5 as AS 65501 (external) — not yet confederation-aware
8. R7 must also migrate before confederation eBGP works — document this dependency

### Task 16: Complete Migration (South)

1. Migrate south routers (R7, R8, R13-R18) to sub-AS 65502
2. On R7: `no router bgp 64512` → `router bgp 65502` with confederation config
3. Repeat for all south routers
4. Verify: confederation eBGP R5↔R7 comes up
5. Verify: `show ip bgp vpnv4 all summary` — routes flowing between sub-ASes
6. End-to-end verification:
   - `ping vrf Customer_A 1.1.1.1 source 9.9.9.9` from R8 — reaches R1 via confederation
   - `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` on R8 — AS-PATH shows `(65501) 65001`
7. Verify all CEs: R1, R9, R11, R12, R19, R20 have full connectivity to their VPN peers
8. **Migration complete:** document total outage time per router

---

## CCIE+ Challenges

### Challenge 1: Three-Way Confederation Split

1. Split AS 64512 into THREE sub-ASes:
   - Sub-AS 65501: R2, R3, R4 (northwest)
   - Sub-AS 65502: R5, R6, R7 (northeast)
   - Sub-AS 65503: R8, R13-R18 (south)
2. Configure confederation eBGP between all pairs: 65501↔65502, 65502↔65503, 65501↔65503
3. Verify: full vpnv4 reachability across all three sub-ASes
4. Test: remove one inter-sub-AS link — verify traffic reroutes via third sub-AS
5. **Design question:** when would three sub-ASes make sense? (Answer: three geographic regions)

### Challenge 2: Confederation with Diverse AF (vpnv4 + vpnv6 + L2VPN)

1. Enable vpnv6 address-family across confederation eBGP peers
2. Enable L2VPN VPLS address-family (if supported on IOS 15.2)
3. Verify: vpnv6 routes cross confederation boundary with attributes preserved
4. Verify: confederation eBGP carries multiple address-families simultaneously
5. **Gotcha:** ensure `send-community both` and `next-hop-unchanged` applied per AF

### Challenge 3: Confederation Loop Prevention Verification

1. Create a routing loop scenario:
   - R2 advertises prefix → R5 → R7 (confederation eBGP) → R13 → back to R5 (via R6↔R13 confederation link?)
2. Verify: BGP confederation loop detection prevents loops
   - Routes containing local sub-AS in AS_CONFED_SEQUENCE are rejected
3. On R5: `show ip bgp vpnv4 all 1.1.1.1` — verify AS_CONFED_SEQUENCE
4. Manually inject a route with sub-AS 65501 already in path → verify R2 rejects it
5. **Mechanism:** same as eBGP AS-PATH loop detection but applied to confederation segments

### Challenge 4: Confederation eBGP Multi-Path

1. Configure `maximum-paths 2` under vpnv4 for confederation eBGP paths
2. With two confederation eBGP links (R5↔R7, R6↔R13): verify load-sharing
3. On R2: `show ip bgp vpnv4 vrf Customer_A 9.9.9.9` — two paths installed
4. Verify: `show ip cef vrf Customer_A 9.9.9.9` — two next-hops in CEF
5. Shut one confederation link — verify traffic shifts to surviving link
6. Restore — verify load-sharing resumes

### Challenge 5: Hot Migration — Reduce Outage with BGP AS Migration

1. Research `bgp bestpath as-path multipath-relax` and `local-as` for smoother migration
2. On R2: use `local-as 64512 no-prepend replace-as` during migration:
   - Allows R2 to respond to both AS 64512 and AS 65501 sessions simultaneously
3. This permits a rolling migration where some routers are already confederated while others are not
4. Verify: during migration, R1 (CE) still sees AS 64512 on R2 regardless of R2's real AS
5. **Advanced:** document the exact sequence for zero-downtime migration using this technique
6. Remove `local-as` after full migration is complete

---

## Final Validation

By the end of this lab, your network has:

- [ ] AS 64512 split into sub-AS 65501 (north) and sub-AS 65502 (south)
- [ ] Full iBGP mesh within each sub-AS (or sub-AS RR for south)
- [ ] Confederation eBGP peers connecting north and south (R5↔R7, R6↔R13)
- [ ] LOCAL_PREF preserved across confederation boundary (verified end-to-end)
- [ ] MED preserved across confederation boundary
- [ ] AS-PATH shows confederation segments in parentheses internally
- [ ] External CEs see only AS 64512 — sub-AS numbers never leaked
- [ ] Redundant confederation eBGP links providing failover
- [ ] Hybrid confederation+RR within south sub-AS reducing session count
- [ ] Full L3VPN connectivity restored across all customers
- [ ] Migration procedure documented with per-router outage times
- [ ] (CCIE+) Three-way confederation split verified
- [ ] (CCIE+) Confederation eBGP loop prevention proven
- [ ] (CCIE+) Multi-path load-sharing across confederation links
