# Lab 21: BGP Fundamentals for Service Providers — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — adapted for multi-AS BGP scenarios
**Prerequisite:** Lab 1 complete (OSPF + LDP), Lab 2 Sections 1-4 (L3VPN basics)

**End Goal:** A comprehensive understanding of BGP path selection, route filtering, community manipulation, and SP-specific BGP features. By the end, you can design BGP policy for a multi-homed SP peering with upstream providers, customers, and peers — exactly what SPCOR tests.

---

## Topology Adaptation

For this lab, the 20-router topology is split into multiple ASes to simulate real SP peering:

```
AS 64512 (Your SP): R2, R3, R4, R5, R6, R7, R8 (core + PEs)
AS 65001 (Customer A - dual-homed): R1 (primary via R2), R9 (backup via R8)
AS 65011 (Customer B): R11 (single-homed via R8)
AS 65012 (Customer C): R12 (single-homed via R2)
AS 64513 (Peer SP): R13, R14, R15, R16 (south core)
AS 65019 (Customer of Peer): R19 (behind R17)
AS 65020 (Customer of Peer): R20 (behind R18)
AS 64513 PEs: R17, R18 (peer SP's PEs)

eBGP Peerings:
  R2 ↔ R1 (customer)
  R2 ↔ R12 (customer)
  R8 ↔ R9 (customer)
  R8 ↔ R11 (customer)
  R6 ↔ R13 (SP peering — inter-AS eBGP)
  R7 ↔ R14 (SP peering — backup inter-AS)

iBGP (within AS 64512):
  R2, R8 peer with RR R3 and R7 (as existing)
```

---

## Section 1: eBGP Peering Fundamentals

### Task 1: Establish eBGP with Customers

1. Configure eBGP between R2 (AS 64512) and R1 (AS 65001) using directly connected IPs
2. Configure eBGP between R8 (AS 64512) and R9 (AS 65001) using directly connected IPs
3. Configure eBGP between R2 and R12 (AS 65012)
4. Configure eBGP between R8 and R11 (AS 65011)
5. On each CE: advertise their loopback(s) via `network` command
6. Verify: `show ip bgp summary` on R2 — sessions Established with R1 and R12
7. Verify: `show ip bgp` on R2 — see customer prefixes
8. Verify: R2 can ping 1.1.1.1 (R1's loopback)

### Task 2: Establish eBGP with Peer SP

1. Configure eBGP between R6 (AS 64512) and R13 (AS 64513) using link IPs
2. Configure eBGP between R7 (AS 64512) and R14 (AS 64513) — backup peering
3. R13 and R14 advertise their loopbacks + R17/R18/R19/R20 prefixes
4. Verify: `show ip bgp summary` on R6 — session with R13 Established
5. Verify: `show ip bgp` on R6 — see peer SP prefixes
6. Configure `ebgp-multihop` if peering via loopbacks instead of connected IPs

### Task 3: iBGP Full Mesh / Route Reflectors

1. Ensure R2 and R8 peer with RRs (R3, R7) for IPv4 unicast (in addition to vpnv4)
2. R3 and R7 reflect IPv4 unicast routes between R2, R8, R6, R7
3. Verify: routes learned from eBGP on R2 are reflected to R8 via RR
4. Verify: `show ip bgp 1.1.1.1` on R8 — shows route via RR with ORIGINATOR_ID R2
5. Key: iBGP next-hop must be reachable (use `next-hop-self` on RRs or at eBGP ingress)

### Task 4: Next-Hop-Self

1. Problem: R2 learns 1.1.1.1 from R1 with next-hop 192.168.12.1 (R1's link IP)
2. R8 receives the route via RR — but 192.168.12.1 isn't in R8's routing table!
3. Fix: on R2, configure `neighbor <RR> next-hop-self` for IPv4 AF
4. Verify: `show ip bgp 1.1.1.1` on R8 — next-hop now shows 2.2.2.2 (R2's loopback)
5. Alternative: redistribute connected into IGP (not recommended in SP)

---

## Section 2: BGP Path Selection

### Task 5: Demonstrate the BGP Best Path Algorithm

1. Make R1's prefix (1.1.1.1/32) reachable via TWO paths:
   - Via R2 (primary) — direct eBGP from R1
   - Via R6 (peer) — R1 also advertises to the peer SP who passes it to R6
2. On R8: `show ip bgp 1.1.1.1` — should see both paths
3. Identify: which path is BEST and WHY (step through the algorithm)
4. Document the order: Weight → LOCAL_PREF → locally originated → AS_PATH length → Origin → MED → eBGP over iBGP → IGP metric to next-hop → Router-ID

### Task 6: Weight (Highest Wins — Local Only)

1. On R8: set weight 200 for routes from one specific neighbor:
   `neighbor <IP> weight 200`
2. Verify: `show ip bgp 1.1.1.1` — path with weight 200 becomes best
3. Remove weight — path selection reverts
4. Key: weight is LOCAL to the router (not advertised to anyone)

### Task 7: LOCAL_PREF (Highest Wins — iBGP Wide)

1. On R2: set LOCAL_PREF 200 on routes received from R1:
   - Create route-map: `set local-preference 200`
   - Apply inbound: `neighbor 192.168.12.1 route-map SET-LP in`
2. Verify: `show ip bgp 1.1.1.1` on R8 — path via R2 has LP 200, path via R6 has LP 100 (default)
3. R8 prefers R2's path (higher LOCAL_PREF)
4. Key: LOCAL_PREF is carried in iBGP — all routers in AS see it

### Task 8: AS-PATH Manipulation

1. On the peer SP (R13): prepend AS 64513 twice when advertising to R6:
   `set as-path prepend 64513 64513`
2. Verify: `show ip bgp` on R6 — routes from peer now have longer AS-PATH
3. Result: routes via customer eBGP (shorter AS-PATH) preferred over peer routes
4. Use case: SP makes customer routes preferred over transit/peer routes

### Task 9: MED (Multi-Exit Discriminator)

1. Customer R1 is dual-homed to R2 AND R8 (via R9 in same AS 65001)
2. R1 sets MED 100 toward R2, MED 200 toward R8 (via R9):
   - `neighbor <R2-IP> route-map SET-MED-100 out`
   - `neighbor <R8-IP> route-map SET-MED-200 out` (on R9)
3. Verify: on your SP routers, path via R2 (MED 100) is preferred over R8 (MED 200)
4. Key: MED is compared ONLY between paths from the SAME neighboring AS
5. Enable: `bgp always-compare-med` to compare across different ASes (not default)

---

## Section 3: Route Filtering

### Task 10: Prefix-List Filtering

1. On R2: create a prefix-list blocking R1's specific prefix 11.11.11.11/32:
   ```
   ip prefix-list BLOCK-SPECIFIC seq 5 deny 11.11.11.11/32
   ip prefix-list BLOCK-SPECIFIC seq 10 permit 0.0.0.0/0 le 32
   ```
2. Apply inbound: `neighbor 192.168.12.1 prefix-list BLOCK-SPECIFIC in`
3. Verify: `show ip bgp` on R2 — 11.11.11.11 is gone, 1.1.1.1 still present
4. Remove filter, verify route returns

### Task 11: AS-PATH Access-List Filtering

1. On R6: filter routes from peer SP — only accept routes originating from AS 64513 (not transit):
   ```
   ip as-path access-list 1 permit ^64513$
   ```
2. Apply: `neighbor <R13-IP> filter-list 1 in`
3. Verify: routes that traversed multiple ASes before reaching 64513 are blocked
4. Only routes originated BY the peer SP are accepted
5. Use case: accept only peer's own routes, not their transit customers

### Task 12: Route-Map Filtering (Combining Matches)

1. On R2 inbound from R1: permit only prefixes in 10.0.0.0/8 range with AS-PATH of exactly "65001":
   ```
   ip prefix-list CUSTOMER-RANGE permit 10.0.0.0/8 le 24
   ip as-path access-list 10 permit ^65001$
   route-map CUSTOMER-FILTER permit 10
    match ip address prefix-list CUSTOMER-RANGE
    match as-path 10
   ```
2. Apply inbound
3. Verify: only matching routes accepted
4. Use case: ensure customer only advertises their allocated address space

---

## Section 4: BGP Communities

### Task 13: Standard Communities

1. On R2: tag routes from R1 (customer) with community `64512:100`:
   ```
   route-map TAG-CUSTOMER permit 10
    set community 64512:100
   neighbor 192.168.12.1 route-map TAG-CUSTOMER in
   ```
2. On R6: tag routes from R13 (peer) with community `64512:200`
3. Verify: `show ip bgp community 64512:100` — shows customer routes
4. Verify: `show ip bgp community 64512:200` — shows peer routes
5. IMPORTANT: configure `neighbor <IP> send-community` to propagate communities via iBGP

### Task 14: Community-Based Policy

1. On R6 (outbound toward peer): only advertise routes with community `64512:100` (customers):
   ```
   route-map ADVERTISE-TO-PEER permit 10
    match community CUSTOMER-ONLY
   ip community-list standard CUSTOMER-ONLY permit 64512:100
   neighbor <R13-IP> route-map ADVERTISE-TO-PEER out
   ```
2. Result: peer SP receives your customer routes but NOT routes you learned from other peers
3. Verify: `show ip bgp neighbors <R13-IP> advertised-routes` — only customer routes sent
4. This is standard SP peering policy: "advertise customers, not peers/transit"

### Task 15: Well-Known Communities

1. Tag a specific route with `no-export`:
   `set community no-export`
2. Verify: route is NOT advertised to eBGP peers (stays within AS)
3. Tag with `no-advertise`:
   Verify: route is NOT advertised to ANY BGP peer (kept locally)
4. Tag with `local-AS`:
   Verify: route is NOT advertised outside the local confederation sub-AS
5. Use case: `no-export` on customer backup routes — keeps them internal for failover only

### Task 16: Large Communities (RFC 8092)

1. If supported on your IOS: configure large communities (4-byte ASN compatible):
   `set large-community 64512:1:100`
2. Format: `Global Admin : Local Data 1 : Local Data 2`
3. Use case: action communities — `64512:1:XXX` = set LOCAL_PREF to XXX
4. Implement: route-map on RR that reads large-community and applies LOCAL_PREF
5. This is how modern SPs let customers influence routing policy via communities

---

## Section 5: Advanced BGP Features

### Task 17: BGP Dampening

1. On R6 (peering router): enable dampening for routes from peer SP:
   `bgp dampening 15 750 2000 60`
   (half-life 15min, reuse 750, suppress 2000, max-suppress 60min)
2. Simulate route flap: on R13, flap a prefix repeatedly (shut/no-shut interface or clear bgp)
3. Verify: `show ip bgp dampening dampened-paths` — flapping route is suppressed
4. Verify: `show ip bgp dampening flap-statistics` — shows flap count and penalty
5. After penalty decays: route becomes reachable again
6. Use case: protect your network from unstable peer routes causing constant reconvergence

### Task 18: Conditional Advertisement

1. On R2: advertise a default route to R1 ONLY if the path to internet (via R6 peer) exists:
   ```
   neighbor 192.168.12.1 advertise-map SEND-DEFAULT exist-map CHECK-INTERNET
   ```
2. `SEND-DEFAULT` matches 0.0.0.0/0; `CHECK-INTERNET` matches a specific peer route
3. Verify: R1 receives default route
4. Simulate: break peering with R6 → default route withdrawn from R1
5. Restore peering → default route re-advertised to R1
6. Use case: don't advertise default to customer if you can't actually reach the internet

### Task 19: BGP Soft Reconfiguration

1. Configure `neighbor <IP> soft-reconfiguration inbound` on R2 for R1
2. Change inbound policy (add new filter) — verify: `clear ip bgp <IP> soft in`
3. Observe: session stays UP, routes re-evaluated with new policy
4. Compare: without soft-reconfig, `clear ip bgp <IP>` tears down the session (outage!)
5. Modern alternative: `neighbor <IP> route-refresh` (supported if both peers support capability)

### Task 20: BGP Maximum-Prefix

1. On R2: `neighbor 192.168.12.1 maximum-prefix 10 80 restart 5`
2. Meaning: if R1 sends >10 prefixes, tear down session. Warn at 80%. Restart after 5 minutes.
3. Test: make R1 advertise 15 prefixes — session gets torn down
4. Verify: `show ip bgp summary` — state shows "Idle (PfxCt)"
5. Wait 5 minutes — session auto-restarts
6. Use case: protect your router from customer accidentally leaking full internet table (800K+ routes)

---

## CCIE+ Challenges

### Challenge 1: Outbound Route Filtering (ORF)

1. Configure ORF (prefix-based) between R2 and R1
2. R1 sends its prefix-list filters TO R2 via BGP capability
3. R2 applies them OUTBOUND — only sends what R1 wants
4. Benefit: reduces unnecessary BGP updates (R2 never sends what R1 would drop anyway)

### Challenge 2: BGP Add-Path

1. Configure Add-Path on RRs (R3, R7) to advertise MULTIPLE paths to clients
2. Without Add-Path: RR only reflects the best path
3. With Add-Path: RR reflects best + second-best
4. Benefit: faster convergence (backup path already known if best fails)

### Challenge 3: BGP Graceful Shutdown (GSHUT)

1. Before maintenance on R2: set community `GRACEFUL_SHUTDOWN` on all routes
2. Peers see this and lower LOCAL_PREF to 0 (drain traffic away from R2)
3. Wait for traffic to shift → then safely shut down R2
4. Implements RFC 8326 — graceful maintenance without traffic loss

### Challenge 4: BGP Flowspec (Basic)

1. Concept: advertise traffic filtering rules via BGP (for DDoS mitigation)
2. Configure a flowspec rule that drops traffic to 1.1.1.1 with specific DSCP
3. Verify: rule propagated via BGP to other routers
4. Use case: SP can remotely trigger ACLs across the network without touching each router

### Challenge 5: BGP PIC (Prefix Independent Convergence)

1. Enable BGP PIC: `bgp additional-paths install` + `bgp bestpath prefix-independent`
2. Install backup path in CEF alongside best path
3. When best path fails: instant switchover to backup (sub-second) without waiting for BGP reconvergence
4. Verify: `show ip cef <prefix> internal` — shows backup path pre-installed

---

## Final Validation

By the end of this lab, your network has:

- [ ] eBGP peerings with customers (multi-homed) and peer SP
- [ ] iBGP with Route Reflectors for IPv4 unicast + next-hop-self
- [ ] Full BGP path selection demonstrated (Weight, LP, AS-PATH, MED, IGP cost)
- [ ] Route filtering: prefix-lists, AS-PATH ACLs, route-maps
- [ ] Community tagging and community-based outbound policy
- [ ] Dampening protecting against flapping peer routes
- [ ] Conditional advertisement for smart default-route injection
- [ ] Maximum-prefix protecting against route leaks
- [ ] (CCIE+) ORF, Add-Path, Graceful Shutdown, Flowspec, PIC
