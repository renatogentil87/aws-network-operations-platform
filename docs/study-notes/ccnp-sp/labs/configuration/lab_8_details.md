# Lab 8: BGP Path Control & SP Scalability — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 7 CEs. Full L3VPN operational with Route Reflectors.
**Prerequisite:** Lab 2 complete (RRs on R3/R7, all VPNs working via RR-reflected vpnv4)

**End Goal:** Master BGP path manipulation for SP traffic engineering — controlling which exit point traffic uses, implementing communities for scalable policy, protecting the network from CE route explosions, and optimizing convergence. By the end, you have the BGP toolkit that real SPs use to manage hundreds of customers and peers.

---

## Section 1: BGP Best-Path Selection — Understand the Decision Chain

### Task 1: Establish Multi-Path Baseline

1. Ensure R1 is multi-homed: R1↔R2 (existing eBGP) AND add R1↔R8 as second PE-CE link
   - On R8: add VRF Customer_A interface toward R1 (use available interface, or use an intermediate link)
   - **Alternative if no physical link:** Configure R9 to readvertise R1's routes, creating two paths to R1 (via R2 and via R8→R9→R1)
   - Simplest option: just use the existing topology where R1 connects to R2 and R9 connects to R8 — they're both in Customer_A and this gives R8 a "via R2 RR-reflected" path vs its own direct path
2. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — verify at least one path exists (via R2, reflected by RR)
3. On R2: `show ip bgp vpnv4 vrf Customer_A 9.9.9.9` — verify path from R8 (reflected by RR)
4. Document: note the default best-path attributes (weight, local-pref, AS-path, origin, MED, IGP cost to next-hop)

### Task 2: Weight — Cisco-Specific Highest Priority

1. On R8: for the vpnv4 session to R3 (RR): `neighbor 3.3.3.3 weight 500` (affects all routes from this RR)
2. On R8: for the vpnv4 session to R7 (RR): `neighbor 7.7.7.7 weight 100`
3. Verify: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — best path is via R3 (weight 500 > 100)
4. Swap: set R7 weight to 600, R3 weight to 500
5. Verify: best path changes to R7 (weight 600 wins)
6. Remove all weight config — verify best-path reverts to default selection
7. **Key point:** weight is LOCAL to the router — never advertised, never visible to peers

### Task 3: Local-Preference — AS-Wide Path Selection

1. On R2 (ingress PE): create a route-map for routes received from R1 (CE):
   - Match R1's loopback 1.1.1.1/32 → set local-preference 200
   - All other routes → local-preference 100 (default)
2. Apply inbound on R2's PE-CE session: `neighbor 192.168.12.1 route-map SET-LOCPREF in`
3. Verify on R2: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — local-pref 200
4. Verify on R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — local-pref 200 (carried via RR)
5. **Key point:** local-pref is advertised within the AS (via iBGP/RR) — ALL PEs see it
6. If R17 also imports Customer_A: verify R17 also sees local-pref 200 for 1.1.1.1
7. Remove the route-map — verify all routes revert to local-pref 100

### Task 4: AS-PATH — Customer-Controlled Preference

1. On R1 (CE): create a route-map for the session toward R2:
   - For loopback 11.11.11.11/32: `set as-path prepend 65001 65001 65001` (make it longer)
   - For loopback 1.1.1.1/32: no prepend (normal length)
2. Apply outbound on R1: `neighbor 192.168.12.2 route-map PREPEND out`
3. On R2: `show ip bgp vpnv4 vrf Customer_A` — compare AS-PATH lengths:
   - 1.1.1.1 should be "65001" (length 1)
   - 11.11.11.11 should be "65001 65001 65001 65001" (length 4)
4. On R8: verify both routes visible — 1.1.1.1 preferred (shorter AS-PATH) if multiple exits exist
5. **SP perspective:** this is how customers influence traffic INBOUND to their sites
6. Remove the prepend — verify AS-PATH returns to normal

### Task 5: MED — Prefer Specific PE Exit

1. On R1: advertise loopback 1.1.1.1 to R2 with MED 100:
   - Route-map: `set metric 100`
2. If R1 has a second PE link (or via RR reflection from another site): configure MED 200 on alternate path
3. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — if two paths exist with same AS, lower MED wins
4. **Key constraint:** MED is only compared between paths from the SAME neighboring AS
5. Verify: `show ip bgp vpnv4 vrf Customer_A` — confirm MED value appears in path attributes
6. **SP use case:** customer tells SP "prefer my primary link (low MED) over backup (high MED)"
7. Remove MED config — return to default

---

## Section 2: Communities for Scalable Policy

### Task 6: Tag Routes with Standard Communities

1. On R1 (CE): create a route-map tagging all routes with community 64512:100:
   - `set community 64512:100 additive`
2. Apply outbound toward R2
3. On R2: `show ip bgp vpnv4 vrf Customer_A community` — verify routes carry community 64512:100
4. On R2: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — community attribute visible
5. Verify: community is preserved through the RR (R3/R7) to R8
6. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — confirm community arrived intact
7. **Critical:** on R2, ensure `neighbor <RR> send-community both` is configured (required for community propagation)

### Task 7: Use Communities to Set Local-Preference on Remote PE

1. On R8: create a route-map for routes received from RR:
   - Match community 64512:100 → set local-preference 150
   - Match community 64512:200 → set local-preference 50
   - No match → local-preference 100 (default)
2. Apply inbound on R8's session to R3: `neighbor 3.3.3.3 route-map COMMUNITY-POLICY in`
3. On R1: change community to 64512:200 — readvertise
4. On R8: verify local-pref dropped to 50 for R1's routes
5. Change back to 64512:100 — verify local-pref goes to 150
6. **SP model:** customer "signals" the SP via communities, SP applies policy automatically
7. This scales to thousands of customers — each community triggers a predefined action

### Task 8: Well-Known Communities — NO_EXPORT and NO_ADVERTISE

1. On R1: advertise loopback 11.11.11.11 with community no-export:
   - `set community no-export additive`
2. On R2: verify route is in BGP table
3. On R8: `show ip bgp vpnv4 vrf Customer_A 11.11.11.11` — route should NOT appear (no-export prevents iBGP advertisement beyond the AS boundary... but in VPN context, check: does it cross the RR?)
4. **Note:** no-export in VPN context may behave differently than in global BGP. Test and document the actual behaviour.
5. Try no-advertise: `set community no-advertise` — this prevents ANY advertisement (even to iBGP)
6. Verify: route stays only on the ingress PE (R2) and is not reflected
7. Revert — remove special communities

---

## Section 3: Protecting the SP from Customer Route Explosions

### Task 9: Maximum-Prefix Limits

1. On R2: `neighbor 192.168.12.1 maximum-prefix 10 80 warning-only` under VRF Customer_A
   - Warns at 80% (8 routes), warning-only means session stays up
2. On R1: create multiple loopbacks and advertise them (Loopback1 through Loopback12)
3. Verify: R2 logs a warning when R1 exceeds 8 prefixes
4. Verify: session remains UP (warning-only mode)
5. Change to strict mode: `neighbor 192.168.12.1 maximum-prefix 10` (no warning-only)
6. Verify: when R1 exceeds 10 prefixes, R2 TEARS DOWN the session
7. Check: `show ip bgp vpnv4 vrf Customer_A summary` — session shows "Idle (PfxCt)" state
8. Fix: `clear ip bgp 192.168.12.1 vrf Customer_A` after removing excess routes
9. **SP rule:** ALWAYS configure max-prefix on PE-CE sessions. Never trust customer prefix counts.

### Task 10: Prefix-List Filtering — Surgical Control

1. On R2: create a prefix-list "CUSTOMER_A_ALLOWED":
   - `permit 1.1.1.0/24 le 32` (allow R1's /32 loopbacks in 1.1.1.x range)
   - `permit 11.11.11.0/24 le 32`
   - `deny 0.0.0.0/0 le 32` (deny everything else)
2. Apply inbound: `neighbor 192.168.12.1 prefix-list CUSTOMER_A_ALLOWED in` under VRF
3. On R1: advertise a bogus route (e.g., 10.0.0.0/8) — verify it's blocked on R2
4. On R1: advertise 1.1.1.1/32 — verify it passes the filter
5. Verify: `show ip bgp vpnv4 vrf Customer_A` on R2 — only permitted prefixes present
6. **SP model:** this defines the customer's "address space" — anything outside gets dropped

### Task 11: AS-PATH Filtering — Block Hijack Attempts

1. On R2: create an as-path access-list:
   - `ip as-path access-list 10 permit ^65001$` (only routes originated by AS 65001)
   - This blocks routes that R1 might transit from other ASes (hijacking risk)
2. Apply: `neighbor 192.168.12.1 filter-list 10 in` under VRF
3. On R1: advertise a route with AS-PATH "65001 65999" (pretend R1 is transiting from AS 65999)
4. Verify: R2 rejects it (AS-PATH doesn't match "^65001$")
5. On R1: advertise route with just AS 65001 — verify it's accepted
6. **SP model:** only accept routes that the customer originated — never let CEs become transit

---

## Section 4: BGP Convergence and Stability

### Task 12: BGP Graceful Restart

1. On R2: `bgp graceful-restart` under router bgp 64512
2. On R3 (RR): `bgp graceful-restart`
3. On R8: `bgp graceful-restart`
4. Verify: `show ip bgp neighbors 3.3.3.3 | include Graceful` — GR capability negotiated
5. Start continuous ping from R1 to R9 (repeat 10000, timeout 1)
6. On R2: `clear ip bgp 3.3.3.3` — reset session to RR
7. During restart (watch the ping): count packet loss
8. Verify: R8 retains R2's routes as "stale" during the restart timer (routes from R2 survive)
9. After session re-establishes: stale routes refreshed
10. Without GR: repeat — measure packet loss (should be much higher as routes immediately withdrawn)

### Task 13: BFD for BGP — Fast Peer Detection

1. On R2 and R3: BFD should be running on the direct link (from Lab 7)
2. Register BGP with BFD: under router bgp, `neighbor 3.3.3.3 fall-over bfd`
3. On R3: `neighbor 2.2.2.2 fall-over bfd`
4. Verify: `show ip bgp neighbors 3.3.3.3 | include BFD` — "Using BFD to detect fast fallover"
5. Kill the link between R2 and R3 — BGP detects failure via BFD (sub-second) instead of hold timer (180s default)
6. **Note:** BFD for BGP only works for directly connected peers. For loopback-based iBGP: use `fall-over` with a route-map tracking the next-hop instead
7. Configure `neighbor 3.3.3.3 fall-over` (without BFD) for loopback-peered sessions — this uses the routing table to detect reachability loss

### Task 14: BGP Next-Hop Tracking and Dampening

1. On R2: `bgp nexthop trigger-delay critical 0 non-critical 3000`
   - Critical: 0ms delay (immediate action for next-hop loss)
   - Non-critical: 3000ms (3 second delay for next-hop metric changes)
2. Verify: `show ip bgp nexthop` — all next-hops tracked
3. Kill a core link: observe how quickly BGP reacts to next-hop becoming unreachable
4. With `critical 0`: BGP should react within the IGP convergence time (not wait for BGP scanner)
5. Compare: set `critical 5000` (5 second delay) — BGP now takes longer to react
6. Revert to `critical 0 non-critical 3000` — optimal for production

---

## Section 5: RT-Constrained Distribution (Scalability)

### Task 15: The Problem — Unnecessary Route Distribution

1. Current state: RR (R3) reflects ALL vpnv4 routes to ALL PEs
2. On R17: `show ip bgp vpnv4 all summary` — count total prefixes received
3. R17 only has Customer_D (RT 64512:400) — but it receives Customer_A, B, C, E routes too
4. On R18: same problem — receives routes for VRFs it doesn't have locally
5. In a real SP with 10,000 customers: every PE would carry the entire vpnv4 table (millions of routes)
6. This wastes memory and CPU on PEs that only serve a few customers

### Task 16: Enable RT-Constraint (RFC 4684)

1. On R3 (RR): under address-family rtfilter unicast:
   - `neighbor 2.2.2.2 activate`
   - `neighbor 8.8.8.8 activate`
   - `neighbor 17.17.17.17 activate`
   - `neighbor 18.18.18.18 activate`
2. On each PE: enable rtfilter toward the RRs:
   - Under `address-family rtfilter unicast`: `neighbor 3.3.3.3 activate` and `neighbor 7.7.7.7 activate`
3. Wait for convergence (routes may temporarily withdraw and re-advertise)
4. On R17: `show ip bgp vpnv4 all summary` — count prefixes now. Should be MUCH lower.
5. On R17: `show ip bgp vpnv4 all` — should only show Customer_D routes (RT 64512:400)
6. Verify: R17 does NOT have Customer_A, B, or E routes anymore

### Task 17: Prove RT-Constraint is Dynamic

1. On R17: add VRF Customer_A (import RT 64512:100)
2. Wait briefly — R3 should now send Customer_A routes to R17 (RT-filter update triggered)
3. Verify: `show ip bgp vpnv4 vrf Customer_A` on R17 — Customer_A routes now present
4. Remove VRF Customer_A from R17
5. Verify: Customer_A routes disappear from R17 (RR stops sending them)
6. **Proves:** RT-constraint dynamically adjusts what each PE receives based on its configured VRFs
7. On R3: `show ip bgp rtfilter unicast` — shows which RTs each PE is requesting

---

## CCIE+ Challenges

### Challenge 1: Hierarchical Route Reflectors

1. Build a two-tier RR hierarchy:
   - Tier 1: R3 (top-level RR)
   - Tier 2: R6 (serves R2, R17) and R7 (serves R8, R18)
2. R6 and R7 peer with R3 as RR clients
3. R2, R17 peer with R6 only. R8, R18 peer with R7 only.
4. Verify: routes from R2 reach R8: R2→R6→R3→R7→R8
5. Verify: all VPN connectivity still works
6. Shut R6 — R2 and R17 lose connectivity. Fix: add R7 as backup for R6's clients
7. **Design question:** in what scale scenario would you need hierarchical RRs? (Answer: 500+ PEs)

### Challenge 2: BGP Add-Path (Multiple Best Paths)

1. On R3 (RR): `bgp additional-paths select all` under address-family vpnv4
2. On R3: `neighbor <PE> additional-paths send receive` for all PE clients
3. On each PE: `bgp additional-paths receive` under vpnv4
4. With R1 multi-homed to R2 and second PE: RR normally reflects only ONE best path
5. With add-path: RR reflects ALL available paths to R1
6. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — verify MULTIPLE paths visible (not just best)
7. Benefit: if best path fails, backup already in BGP table — instant convergence
8. **Note:** verify add-path is supported on your IOS 15.2 image. If not, document the concept.

### Challenge 3: BGP Confederations (Alternative to RR)

1. Remove all Route Reflector configuration
2. Split AS 64512 into sub-ASes:
   - Sub-AS 65100: R2, R3, R4, R6 (full iBGP mesh within)
   - Sub-AS 65200: R5, R7, R8, R13-R18 (full iBGP mesh within)
3. On all routers: `bgp confederation identifier 64512`
4. On Sub-AS 65100 members: `bgp confederation peers 65200`
5. On Sub-AS 65200 members: `bgp confederation peers 65100`
6. Configure eBGP-like sessions between sub-ASes (R6↔R7 or R4↔R5 as confederation peers)
7. Verify: vpnv4 routes flow between sub-ASes
8. Verify: CEs still see AS 64512 (confederation transparent externally)
9. **Tradeoff vs RR:** confederations are more complex to configure but avoid RR's suboptimal routing

### Challenge 4: BGP Optimal Route Reflection (ORR)

1. Re-enable RR (R3, R7) with PE clients
2. Problem: R3 is closest to R2, so it naturally prefers R2 as next-hop for Customer_A routes
3. R3 reflects this "best path via R2" to ALL clients — even R18 which is much closer to R8
4. Enable ORR on R3: `bgp optimal-route-reflection <group-name>`
   - Group clients by topology proximity
5. With ORR: R3 calculates best path FROM EACH CLIENT'S perspective
6. Verify: R18 may now receive "best path via R8" (not via R2) because R8 is closer to R18
7. **Note:** ORR requires IOS 15.4+ or IOS-XR. If not available on your image, document the concept and explain why it matters.

### Challenge 5: Full BGP Convergence Stack

1. Deploy all convergence optimizations simultaneously:
   - BFD on all directly connected BGP sessions
   - `bgp fall-over` for loopback-peered sessions
   - `bgp nexthop trigger-delay critical 0`
   - `bgp graceful-restart`
   - RT-constraint (reduce update volume)
   - Add-path (pre-install backup paths)
2. Run continuous ping across all VPNs (R1→R9, R12→R11, R19→R20)
3. Kill a PE-to-P link (e.g., R2's Gi1/0 toward R3)
4. Measure: end-to-end VPN convergence time (from first dropped ping to full recovery)
5. Target: < 3 seconds for BGP-level convergence (VPN traffic recovery)
6. Kill an RR (shut R3's loopback) — measure impact
7. With all optimizations: VPN traffic should survive RR failure with minimal loss
8. Document: which optimization had the biggest individual impact on convergence time?

### Challenge 6: Peer-Group and Template Optimization

1. Current state: each PE has individual neighbor statements for each RR
2. Refactor using peer-groups (or peer-templates on IOS 15.2):
   - Create `peer-group VPNv4-RR`
   - Set common attributes: update-source, next-hop-self, send-community both
   - Assign all RR sessions to the peer-group
3. Verify: configuration is cleaner, behaviour unchanged
4. On the RR: create peer-group for all PE clients
5. Benefit: reduces config lines, makes policy changes atomic (change once, applies to all)
6. **Scale question:** with 50 PEs, how many config lines does this save? (Significant)

---

## Final Validation

By the end of this lab, your network has:

- [ ] BGP best-path selection understood and verified (weight > local-pref > AS-PATH > MED)
- [ ] Local-preference proven to propagate AS-wide via RR
- [ ] AS-PATH prepend providing customer-controlled primary/backup
- [ ] Communities tagging routes and triggering policy on remote PEs
- [ ] send-community configured (communities surviving RR reflection)
- [ ] Maximum-prefix limits protecting all PE-CE sessions
- [ ] Prefix-list filtering defining per-customer allowed address space
- [ ] AS-PATH filtering preventing customer hijack/transit attempts
- [ ] BGP graceful restart preserving forwarding during session restarts
- [ ] BGP next-hop tracking with immediate reaction to next-hop loss
- [ ] RT-Constraint reducing vpnv4 distribution to only interested PEs
- [ ] RT-Constraint proven dynamic (add VRF → routes appear; remove → disappear)
- [ ] (CCIE+) Hierarchical RR with tier-1/tier-2 topology
- [ ] (CCIE+) Add-path providing multiple paths for faster convergence
- [ ] (CCIE+) Confederations as RR alternative (concept proven)
- [ ] (CCIE+) Full convergence stack achieving < 3s VPN recovery
