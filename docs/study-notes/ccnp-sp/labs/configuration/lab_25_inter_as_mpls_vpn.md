# Lab 25: Inter-AS MPLS VPN — Options A, B, C — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 2 RRs, 6 CEs. Full MPLS core with L3VPN operational.
**Prerequisite:** Lab 2 complete (L3VPN with MP-BGP VPNv4, RRs on R3/R7, multiple VRFs working)

**End Goal:** Extend MPLS L3VPN services across multiple autonomous systems. Configure all three Inter-AS options — Option A (back-to-back VRF), Option B (VPNv4 at ASBR), and Option C (multihop VPNv4 + labeled unicast) — understanding the scalability, security, and complexity tradeoffs of each. By the end, you can design multi-SP VPN interconnects, explain why Tier-1 ISPs prefer Option C for internal inter-AS and Option A/B for peering, and troubleshoot end-to-end label stacks across AS boundaries.

---

## Topology Adaptation

Split the 20-router topology into TWO autonomous systems:

```
┌─────────────────── AS 64512 (West) ───────────────────┐   ┌─────────── AS 64513 (East) ──────────┐
│                                                         │   │                                       │
│  CE: R1 (AS65001)                                       │   │                          CE: R9 (AS65001) │
│       │                                                 │   │                          │              │
│  PE: R2                                                 │   │                     PE: R8             │
│       │                                                 │   │                          │              │
│  P:  R3(RR)─R4─R5─R6                                   │   │         R7(RR)─R13─R14─R15─R16         │
│                   │                                     │   │         │                              │
│              ASBR: R6 ═══════════════════════════════════╪═══╪═══ ASBR: R13                           │
│                                                         │   │                                       │
│  CE: R11 (AS65011)──PE: R17                             │   │                     PE: R18──CE: R19   │
│                                                         │   │                                       │
└─────────────────────────────────────────────────────────┘   └───────────────────────────────────────┘

Inter-AS Link: R6 (AS 64512) ←→ R13 (AS 64513) 
              10.10.6.1/30      10.10.6.2/30

West IGP: OSPF area 0 (R2, R3, R4, R5, R6, R17)
East IGP: OSPF area 0 (R7, R8, R13, R14, R15, R16, R18)
```

**Key Changes from Single-AS:**
- R6 becomes an ASBR (border between AS 64512 and AS 64513)
- R13 becomes an ASBR (border for AS 64513)
- No IGP adjacency between R6 and R13 (separate OSPF domains)
- Each AS has its own RR (R3 for West, R7 for East)
- Customer_A spans both ASes: R1 ↔ R2 (West PE) and R9 ↔ R8 (East PE)

---

## Section 1: Understanding Inter-AS Requirements

### Task 1: Document Why Inter-AS Is Needed

1. Scenarios requiring Inter-AS MPLS VPN:
   - **Multi-provider:** Customer buys VPN service from two different ISPs
   - **Carrier's Carrier (CsC):** ISP provides MPLS backbone to smaller ISP
   - **Large SP with multiple ASes:** Tier-1 SPs use different AS numbers per region/acquisition
   - **Enterprise with MPLS WAN from two providers:** needs VPN connectivity end-to-end

2. Fundamental problem: single-AS MPLS VPN relies on:
   - iBGP VPNv4 sessions between PEs (same AS = iBGP)
   - LDP/RSVP-TE providing transport labels between PEs (same IGP domain)
   - Neither works across AS boundaries

3. Three solutions (RFC 4364, Section 10):
   - **Option A (back-to-back VRF):** simple, per-VRF peering at ASBR — scales poorly
   - **Option B (VPNv4 at ASBR):** VPNv4 eBGP between ASBRs — moderate scalability
   - **Option C (multihop):** VPNv4 between PEs/RRs + labeled unicast for reachability — best scalability

### Task 2: Prepare the Multi-AS Topology

1. On R6 (ASBR-West), remove OSPF adjacency toward R13:
   ```
   interface Serial2/0
    description Link to R13 (Inter-AS)
    ip address 10.10.6.1 255.255.255.252
    no ip ospf 1 area 0
   ```

2. On R13 (ASBR-East), remove OSPF adjacency toward R6:
   ```
   interface Serial2/0
    description Link to R6 (Inter-AS)
    ip address 10.10.6.2 255.255.255.252
    no ip ospf 1 area 0
   ```

3. Verify separation:
   ```
   ! On R2 (West PE):
   show ip route 8.8.8.8
   ! Should NOT be reachable — R8's loopback is in the East AS
   
   ! On R8 (East PE):
   show ip route 2.2.2.2
   ! Should NOT be reachable — R2's loopback is in the West AS
   ```

4. Verify each AS still works internally:
   ```
   ! West: R2 can still reach R6 loopback
   ping 6.6.6.6 source 2.2.2.2
   
   ! East: R8 can still reach R13 loopback
   ping 13.13.13.13 source 8.8.8.8
   ```

---

## Section 2: Option A — Back-to-Back VRF (VRF-to-VRF)

### Concept

- ASBRs act as PE routers to each other
- Each ASBR has VRFs configured for every customer VPN that crosses the boundary
- Sub-interfaces on the inter-AS link — one per VRF
- PE-CE routing protocol (eBGP, static, OSPF) runs on each VRF sub-interface
- **Result:** each AS is independent — no VPNv4, no label exchange between ASes
- **Drawback:** one sub-interface per VRF per ASBR link = O(n) scaling problem

### Task 3: Configure Option A on ASBR-West (R6)

1. Create the VRF on R6 (if not already present from internal VPN):
   ```
   ip vrf CUSTOMER-A
    rd 64512:100
    route-target export 64512:100
    route-target import 64513:100
   ```
   **Note:** importing RT 64513:100 because East AS will export with its own AS-numbered RT.

2. Create sub-interface toward R13 for Customer_A:
   ```
   interface Serial2/0.100 point-to-point
    description Inter-AS Option A — Customer_A to R13
    ip vrf forwarding CUSTOMER-A
    ip address 10.99.1.1 255.255.255.252
   ```

3. Configure eBGP in VRF toward R13:
   ```
   router bgp 64512
    address-family ipv4 vrf CUSTOMER-A
     neighbor 10.99.1.2 remote-as 64513
     neighbor 10.99.1.2 activate
     neighbor 10.99.1.2 as-override
    exit-address-family
   ```

### Task 4: Configure Option A on ASBR-East (R13)

1. Create the VRF on R13:
   ```
   ip vrf CUSTOMER-A
    rd 64513:100
    route-target export 64513:100
    route-target import 64512:100
   ```

2. Create sub-interface toward R6 for Customer_A:
   ```
   interface Serial2/0.100 point-to-point
    description Inter-AS Option A — Customer_A to R6
    ip vrf forwarding CUSTOMER-A
    ip address 10.99.1.2 255.255.255.252
   ```

3. Configure eBGP in VRF toward R6:
   ```
   router bgp 64513
    address-family ipv4 vrf CUSTOMER-A
     neighbor 10.99.1.1 remote-as 64512
     neighbor 10.99.1.1 activate
     neighbor 10.99.1.1 as-override
    exit-address-family
   ```

### Task 5: Configure Internal VPNv4 Redistribution

1. On R6 — ensure Customer_A routes from internal PEs (R2, R17) reach the VRF and get advertised to R13:
   ```
   ! R6 should be an iBGP VPNv4 client of R3 (RR)
   router bgp 64512
    address-family vpnv4
     neighbor 3.3.3.3 activate
     neighbor 3.3.3.3 send-community extended
   ```
   Routes from R2's VRF Customer_A → RR R3 → R6 VRF → eBGP VRF → R13

2. On R13 — same principle toward R7 (East RR):
   ```
   router bgp 64513
    address-family vpnv4
     neighbor 7.7.7.7 activate
     neighbor 7.7.7.7 send-community extended
   ```

### Task 6: Verify Option A End-to-End

1. Check VRF routing on ASBRs:
   ```
   ! R6:
   show ip route vrf CUSTOMER-A
   ! Should see: local CE routes (from R2 via RR) + remote CE routes (from R13 via eBGP VRF)
   
   ! R13:
   show ip route vrf CUSTOMER-A
   ! Should see: local CE routes (from R8 via RR) + remote CE routes (from R6 via eBGP VRF)
   ```

2. End-to-end ping from CE to CE:
   ```
   ! On R1 (CE, Customer_A West):
   ping 10.10.10.9
   ! Should reach R9's Customer_A interface in East AS
   ```

3. Traceroute — observe NO label stack across the inter-AS link:
   ```
   ! On R1:
   traceroute 10.10.10.9 source 10.10.10.1
   ! You'll see: R1→R2 (unlabeled)→ MPLS core West →R6 (label popped, VRF lookup)
   !             →R13 (new label push, East MPLS core)→R8→R9
   ```

4. Label stack analysis:
   ```
   ! On R2: show mpls forwarding-table vrf CUSTOMER-A 10.10.10.9
   ! Shows 2 labels: outer=LDP to R6, inner=VPN label for Customer_A on R6
   
   ! On R13: show mpls forwarding-table vrf CUSTOMER-A 10.10.10.1  
   ! Shows 2 labels: outer=LDP to R6... wait — R13 sends to R8 with labels
   ```

5. Key observation: **the inter-AS link carries plain IP in the VRF** — no MPLS labels cross the boundary. Each AS has its own independent label space.

### Task 7: Document Option A Tradeoffs

| Aspect | Option A |
|---|---|
| Scalability | Poor — 1 sub-interface per VRF per inter-AS link |
| Security | Excellent — full route filtering per VRF possible |
| Complexity | Low — standard PE-CE peering at the ASBR |
| Provider independence | Full — no trust between ASes needed |
| Label stack at boundary | No labels — plain IP in VRF context |
| Use case | Small number of VPNs, multi-provider with strict isolation |

---

## Section 3: Option B — VPNv4 eBGP at ASBR (Next-Hop-Self + Label Swap)

### Concept

- ASBRs exchange VPNv4 routes via eBGP directly
- ASBR does NOT need VRFs — routes are in the VPNv4 BGP table only
- ASBR performs next-hop-self: rewrites NH to its own address
- ASBR allocates a NEW label per VPNv4 prefix → label swap at boundary
- **Result:** scalable (one eBGP session carries ALL VPNs), no per-VRF config on ASBR
- **Drawback:** ASBR must hold ALL VPNv4 routes from both ASes in memory

### Task 8: Remove Option A Configuration

1. On R6: remove VRF, sub-interface, and VRF BGP config added in Section 2
   ```
   no interface Serial2/0.100
   no ip vrf CUSTOMER-A    ← only if R6 isn't also a PE; otherwise keep VRF but remove ASBR-specific config
   ```
   
2. On R13: same cleanup
   ```
   no interface Serial2/0.100
   no ip vrf CUSTOMER-A
   ```

3. Restore the base inter-AS interface (un-numbered or simple IP):
   ```
   ! R6:
   interface Serial2/0
    ip address 10.10.6.1 255.255.255.252
    no shutdown
   
   ! R13:
   interface Serial2/0
    ip address 10.10.6.2 255.255.255.252
    no shutdown
   ```

### Task 9: Configure VPNv4 eBGP Between ASBRs

1. On R6 (ASBR-West):
   ```
   router bgp 64512
    neighbor 10.10.6.2 remote-as 64513
    !
    address-family vpnv4
     neighbor 10.10.6.2 activate
     neighbor 10.10.6.2 send-community extended
     neighbor 10.10.6.2 next-hop-self
    exit-address-family
   ```

2. On R13 (ASBR-East):
   ```
   router bgp 64513
    neighbor 10.10.6.1 remote-as 64512
    !
    address-family vpnv4
     neighbor 10.10.6.1 activate
     neighbor 10.10.6.1 send-community extended
     neighbor 10.10.6.1 next-hop-self
    exit-address-family
   ```

### Task 10: Enable MPLS on the Inter-AS Link

1. Option B REQUIRES MPLS on the inter-AS link (labels are exchanged):
   ```
   ! R6:
   interface Serial2/0
    mpls bgp forwarding
   
   ! R13:
   interface Serial2/0
    mpls bgp forwarding
   ```
   
   **Note:** We use `mpls bgp forwarding` (NOT `mpls ip`). LDP is not needed between ASBRs. BGP itself allocates and advertises labels for VPNv4 prefixes.

### Task 11: Verify Option B VPNv4 Exchange

1. Check VPNv4 eBGP session between ASBRs:
   ```
   ! R6:
   show ip bgp vpnv4 all summary
   ! Should see R13's address (10.10.6.2) as eBGP peer with VPNv4 routes received
   
   ! R13:
   show ip bgp vpnv4 all summary
   ! Should see R6's address (10.10.6.1) as eBGP peer
   ```

2. Check VPNv4 routes on ASBR:
   ```
   ! R6:
   show ip bgp vpnv4 all
   ! Should see routes from BOTH ASes — local (from RR R3) and remote (from R13 eBGP)
   ! Next-hop for remote routes: 10.10.6.2 → after next-hop-self by R6 toward RR: 6.6.6.6
   ```

3. Check labels allocated by ASBR:
   ```
   ! R6:
   show ip bgp vpnv4 all labels
   ! Each VPNv4 prefix from R13 gets a LOCAL label allocated by R6
   ! R6 advertises this label to internal peers (RR R3) and swaps it for R13's label outbound
   ```

4. End-to-end ping:
   ```
   ! R1 (CE West) → R9 (CE East):
   ping 10.10.10.9 source 10.10.10.1
   ```

5. Label stack analysis — 3 labels at ingress PE:
   ```
   ! On R2:
   show mpls forwarding-table vrf CUSTOMER-A 10.10.10.9 detail
   ! Label stack: [LDP to R6] [VPN label allocated by R6]
   ! Wait — actually 2 labels because R6 does next-hop-self
   
   ! On R6 (ASBR): 
   show mpls forwarding-table
   ! R6 swaps VPN label from R2 → VPN label from R13, then pushes LDP label... 
   ! But there's no LDP to R13! So packet goes with just the VPN label across the inter-AS link
   ```

6. **Key insight:** At the ASBR boundary, the label stack is:
   - Within West AS: `[LDP label to R6] [VPN label (R6-allocated)]`
   - R6 pops outer LDP label (PHP or aggregate), swaps VPN label to R13's VPN label
   - Across inter-AS link: `[R13's VPN label]` — single label
   - R13 receives it, pushes LDP label to reach East PE: `[LDP label to R8] [original VPN label from R8]`
   - Actually R13 does next-hop-self toward R7/R8, so R13 swaps again

### Task 12: RT Filtering on ASBRs (Critical for Scalability)

1. Without RT filtering, ASBRs hold ALL VPNv4 routes from both ASes:
   ```
   ! R6: check how many VPNv4 routes:
   show ip bgp vpnv4 all | count
   ```

2. Apply RT-based ORF (Outbound Route Filtering) or RT-constraint:
   ```
   ! R6 — only accept VPNv4 routes with RTs that local PEs import:
   router bgp 64512
    address-family vpnv4
     neighbor 10.10.6.2 route-map FILTER-INTER-AS in
   
   route-map FILTER-INTER-AS permit 10
    match extcommunity RT-ALLOWED
   
   ip extcommunity-list standard RT-ALLOWED permit rt 64512:100
   ip extcommunity-list standard RT-ALLOWED permit rt 64512:200
   ```

### Task 13: Document Option B Tradeoffs

| Aspect | Option B |
|---|---|
| Scalability | Moderate — ASBR holds all VPNv4 routes (memory pressure) |
| Security | Moderate — RT filtering possible but ASBR sees all routes |
| Complexity | Moderate — VPNv4 eBGP + label management on ASBR |
| Provider independence | Moderate — must agree on RT values or translate |
| Label stack at boundary | VPN label swapped at ASBR; single label on inter-AS link |
| Use case | Medium scale, trusted peer SPs, carrier internal inter-AS |

---

## Section 4: Option C — Multihop VPNv4 + Labeled Unicast (Best Scalability)

### Concept

- VPNv4 routes exchanged **directly between PEs (or RRs)** across AS boundaries via multihop eBGP
- ASBRs provide ONLY reachability to remote PE loopbacks — using labeled unicast (BGP label or LDP)
- ASBRs do NOT touch VPNv4 routes — they just forward labeled packets
- **Result:** ASBRs are thin (only carry PE loopbacks, not VPN routes); RRs/PEs handle VPN intelligence
- **Drawback:** complex setup, requires trust (remote AS PE loopback reachable), 3-label stack

### Architecture:
```
R2(PE) ──iBGP VPNv4──→ R3(RR) ──multihop eBGP VPNv4──→ R7(RR) ──iBGP VPNv4──→ R8(PE)
                                                    
R6(ASBR) ←─BGP labeled unicast─→ R13(ASBR)
  (advertises R2's loopback with label)     (advertises R8's loopback with label)
```

### Task 14: Remove Option B Configuration

1. On R6: remove VPNv4 eBGP toward R13:
   ```
   router bgp 64512
    no neighbor 10.10.6.2
    ! Or specifically:
    address-family vpnv4
     no neighbor 10.10.6.2 activate
   ```

2. On R13: remove VPNv4 eBGP toward R6:
   ```
   router bgp 64513
    no neighbor 10.10.6.1
   ```

3. Keep MPLS enabled on the inter-AS link (still needed for Option C):
   ```
   ! R6 and R13: keep mpls bgp forwarding on Serial2/0
   ```

### Task 15: Configure BGP Labeled Unicast Between ASBRs

1. On R6 — advertise West PE loopbacks with labels to R13:
   ```
   router bgp 64512
    neighbor 10.10.6.2 remote-as 64513
    !
    address-family ipv4
     neighbor 10.10.6.2 activate
     neighbor 10.10.6.2 send-label
     ! Advertise PE loopbacks:
     network 2.2.2.2 mask 255.255.255.255
     network 17.17.17.17 mask 255.255.255.255
     ! Also advertise own loopback (needed for next-hop resolution):
     network 6.6.6.6 mask 255.255.255.255
    exit-address-family
   ```

   **Critical:** `send-label` makes BGP allocate and advertise a label for each IPv4 prefix. This label is used by the remote AS to reach the PE loopback via MPLS (not IP routing).

2. On R13 — advertise East PE loopbacks with labels to R6:
   ```
   router bgp 64513
    neighbor 10.10.6.1 remote-as 64512
    !
    address-family ipv4
     neighbor 10.10.6.1 activate
     neighbor 10.10.6.1 send-label
     network 8.8.8.8 mask 255.255.255.255
     network 18.18.18.18 mask 255.255.255.255
     network 13.13.13.13 mask 255.255.255.255
    exit-address-family
   ```

3. On R6 — redistribute received labeled routes into internal BGP (so R2 can reach R8's loopback):
   ```
   router bgp 64512
    address-family ipv4
     neighbor 3.3.3.3 activate
     neighbor 3.3.3.3 next-hop-self
     neighbor 3.3.3.3 send-label
   ```
   **Note:** R6 must pass the labeled route for 8.8.8.8 to the RR (R3), which reflects it to R2. R2 needs to resolve R8's loopback for the VPNv4 next-hop.

4. On R13 — same toward East RR:
   ```
   router bgp 64513
    address-family ipv4
     neighbor 7.7.7.7 activate
     neighbor 7.7.7.7 next-hop-self
     neighbor 7.7.7.7 send-label
   ```

### Task 16: Configure Multihop VPNv4 Between RRs

1. On R3 (West RR) — multihop eBGP VPNv4 to R7 (East RR):
   ```
   router bgp 64512
    neighbor 7.7.7.7 remote-as 64513
    neighbor 7.7.7.7 ebgp-multihop 255
    neighbor 7.7.7.7 update-source Loopback0
    !
    address-family vpnv4
     neighbor 7.7.7.7 activate
     neighbor 7.7.7.7 send-community extended
     neighbor 7.7.7.7 next-hop-unchanged
    exit-address-family
   ```
   
   **Critical:** `next-hop-unchanged` — R3 does NOT rewrite the VPNv4 next-hop. The route stays with next-hop = R2 (2.2.2.2). The remote PE (R8) must be able to resolve 2.2.2.2 via the labeled unicast path through the ASBRs.

2. On R7 (East RR) — multihop eBGP VPNv4 to R3 (West RR):
   ```
   router bgp 64513
    neighbor 3.3.3.3 remote-as 64512
    neighbor 3.3.3.3 ebgp-multihop 255
    neighbor 3.3.3.3 update-source Loopback0
    !
    address-family vpnv4
     neighbor 3.3.3.3 activate
     neighbor 3.3.3.3 send-community extended
     neighbor 3.3.3.3 next-hop-unchanged
    exit-address-family
   ```

3. Verify RR loopback reachability (R3 must reach R7 and vice versa):
   ```
   ! R3 needs a route to 7.7.7.7 — via labeled unicast through R6→R13
   ! This requires R6 to advertise 7.7.7.7 with send-label internally, 
   ! OR a static route / eBGP IPv4 route for the RR loopbacks
   
   ! Simplest: on R6, also advertise R13's routes received from R13 toward R3:
   ! The labeled unicast session already does this if R6 has next-hop-self + send-label to R3
   ```

### Task 17: Verify Option C End-to-End

1. Verify labeled unicast routes on ASBR:
   ```
   ! R6:
   show ip bgp 8.8.8.8
   ! Should show: learned from R13 (10.10.6.2) with label
   
   show mpls forwarding-table 8.8.8.8
   ! Should show: incoming label (allocated by R6), outgoing label (received from R13), out-interface Serial2/0
   ```

2. Verify PE loopback reachability from remote AS:
   ```
   ! R2 (West PE):
   show ip route 8.8.8.8
   ! Should be reachable via labeled path: R2→...→R6→R13→...→R8
   
   ping 8.8.8.8 source 2.2.2.2
   ```

3. Verify VPNv4 route exchange between RRs:
   ```
   ! R3:
   show ip bgp vpnv4 all
   ! Should see routes from East AS with next-hop = R8's loopback (8.8.8.8)
   ! NOT next-hop = R7 (because next-hop-unchanged)
   
   ! R7:
   show ip bgp vpnv4 all
   ! Should see routes from West AS with next-hop = R2's loopback (2.2.2.2)
   ```

4. Verify VPNv4 on PE:
   ```
   ! R2:
   show ip bgp vpnv4 vrf CUSTOMER-A
   ! Should see routes from R8 (next-hop 8.8.8.8) — resolved via labeled unicast
   ```

5. End-to-end ping:
   ```
   ! R1 (CE West) → R9 (CE East):
   ping 10.10.10.9 source 10.10.10.1
   ```

6. **Label stack analysis — 3 labels!**
   ```
   ! On R2:
   show mpls forwarding-table vrf CUSTOMER-A 10.10.10.9 detail
   ! Label stack (bottom to top):
   !   1. VPN label (from R8, via MP-BGP VPNv4) — identifies VRF on R8
   !   2. BGP labeled unicast label (from R6, for prefix 8.8.8.8) — reaches R8's loopback
   !   3. LDP/IGP label (to reach R6) — standard IGP transport within West AS
   
   ! So: [LDP to R6] [BGP-LU label for 8.8.8.8] [VPN label from R8]
   ```

7. Packet walk:
   ```
   R2 pushes 3 labels → traverses West core (outer LDP label swapped hop-by-hop)
   → arrives at R6: pops LDP label (PHP), swaps BGP-LU label to R13's label
   → crosses inter-AS link with 2 labels: [R13's BGP-LU label for 8.8.8.8] [VPN label]
   → R13: swaps/pops BGP-LU label, pushes LDP label to reach R8
   → traverses East core → arrives at R8: pops LDP (PHP), pops VPN label → IP lookup in VRF
   ```

### Task 18: Document Option C Tradeoffs

| Aspect | Option C |
|---|---|
| Scalability | Excellent — ASBRs hold only PE loopbacks (few), not VPN routes (millions) |
| Security | Lower — remote PE loopbacks must be reachable (larger trust boundary) |
| Complexity | High — 3 layers of BGP sessions, label stacks, careful next-hop handling |
| Provider independence | Low — requires coordination (loopback exchange, trust) |
| Label stack at boundary | 3 labels at ingress PE; 2 labels cross the inter-AS link |
| Use case | Large-scale SP, internal multi-AS (regional ASes within one company) |

---

## Section 5: Comparison and Design Decision Framework

### Task 19: Side-by-Side Comparison

| Criteria | Option A | Option B | Option C |
|---|---|---|---|
| VRF on ASBR | ✅ Yes (per customer) | ❌ No | ❌ No |
| VPNv4 on ASBR | ❌ No | ✅ Yes (all routes) | ❌ No (only PE loopbacks) |
| MPLS across inter-AS | ❌ No (plain IP in VRF) | ✅ Yes (VPN label only) | ✅ Yes (2 labels) |
| Labels in stack (at ingress PE) | 2 | 2 | 3 |
| ASBR memory pressure | Low (per-VRF routes) | High (all VPNv4) | Low (PE loopbacks only) |
| Per-VRF config on ASBR | ✅ Required | ❌ Not needed | ❌ Not needed |
| Adding new VRF requires ASBR change | ✅ Yes | ❌ No (auto via RT) | ❌ No (auto via RT) |
| Commonly used between | Different SPs | Trusted SPs / internal | Internal (same SP, multi-region) |
| RFC 4364 section | 10a | 10b | 10c |

### Task 20: Real-World Deployment Patterns

1. **Tier-1 ISP peering (different companies):** Option A
   - Maximum isolation, minimum trust
   - Peering point has limited VPNs (enterprise customers bridging two ISPs)
   
2. **Large ISP internal (multiple regions):** Option C
   - Sprint, AT&T — different ASes per region (acquisition history)
   - Thousands of VPNs — Option A impossible, Option B ASBR memory problematic
   - Internal trust = labeled unicast between ASBRs is acceptable

3. **Medium ISP buying transit/VPN from upstream:** Option B
   - Upstream provider exports VPNv4 routes, downstream consumes
   - Moderate scale, ASBR memory manageable

---

## Section 6: Carrier's Carrier (CsC) — Bonus Concept

### Task 21: Understand CsC Architecture

1. CsC = a hierarchical VPN model where:
   - **Carrier's Carrier (backbone provider):** provides MPLS transport
   - **ISP Customer:** runs its own MPLS network using the backbone as underlay
   - The ISP customer's PE routers become CEs from the backbone provider's perspective

2. Key difference from regular Inter-AS:
   - In regular L3VPN: CE sends IP → PE adds labels
   - In CsC: CE sends LABELED packets → PE forwards them with MORE labels stacked
   - Result: 3-4 label stack (backbone transport + ISP VPN label + ISP customer route)

3. Configuration concept (reference only — requires IOS 12.4+ features):
   ```
   ! On backbone PE (toward ISP-CE):
   ip vrf ISP-CUSTOMER
    rd 1:1
    route-target both 1:1
   
   interface GigabitEthernet1/0
    ip vrf forwarding ISP-CUSTOMER
    ip address 10.0.0.1 255.255.255.252
    mpls ip          ← KEY: enable MPLS on the VRF interface!
   
   ! This runs LDP between backbone-PE and ISP-CE router
   ! ISP-CE can now build LSPs across the backbone
   ```

4. CsC vs Inter-AS:
   - Inter-AS: extends ONE VPN across AS boundaries
   - CsC: provides MPLS transit to another SP (who runs their own VPN services)

---

## CCIE+ Challenges

### Challenge 1: Option AB Hybrid — Option A for Some VPNs, Option B for Others

On the same ASBR pair (R6 ↔ R13):
- Customer_A: use Option A (maximum isolation — financial customer requirement)
- Customer_B: use Option B (higher scale, trusted customer)
- Document how both coexist on the same physical inter-AS link

Hints:
- Option A uses VRF sub-interfaces
- Option B uses VPNv4 eBGP session
- Both can run simultaneously — different VPNs take different paths through the ASBR

### Challenge 2: Option B with RT Rewrite (Inter-Provider)

Two different SPs with conflicting RT values:
- West uses RT 100:1 for Customer_A
- East uses RT 200:1 for the SAME customer

Configure RT rewrite on the ASBR so that routes arriving with RT 200:1 are re-tagged as 100:1 before being sent internally (and vice versa).

```
! Hint: use route-map with set extcommunity on VPNv4 eBGP session
route-map REWRITE-RT permit 10
 match extcommunity EAST-RT
 set extcommunity rt 100:1 additive
```

### Challenge 3: Option C with Segment Routing (No LDP)

Replace LDP within each AS with SR-MPLS:
- Each PE has a prefix-SID
- BGP labeled unicast between ASBRs now advertises SR labels (prefix-SID + label-index)
- Document how the 3-label stack changes:
  - Label 1: SR prefix-SID of ASBR (instead of LDP)
  - Label 2: BGP-LU label for remote PE loopback
  - Label 3: VPN label

### Challenge 4: Option C with IPv6 — 6VPE Across AS Boundaries

Extend Lab 12 (6PE/6VPE) across the multi-AS topology:
- VPNv6 routes (AFI 2, SAFI 128) exchanged between RRs via multihop eBGP
- Labeled unicast still IPv4 (carries the PE loopbacks)
- Document: does the label stack change? (Answer: no — same 3 labels, VPN label still from vpnv6)

### Challenge 5: Full Migration — Option A → Option B → Option C (Live Traffic)

Design a migration plan that moves from Option A to Option C without dropping customer traffic:
1. Start: Option A working (Section 2 complete)
2. Add Option B in parallel (both options active simultaneously)
3. Verify traffic shifts to Option B
4. Remove Option A config
5. Add Option C in parallel with Option B
6. Verify traffic shifts to Option C
7. Remove Option B config
8. Document: at which steps can you lose traffic? What's the make-before-break strategy?

---

## Troubleshooting Checklist

| Symptom | Check | Common Fix |
|---|---|---|
| VPNv4 routes not received on ASBR (Option B) | `show ip bgp vpnv4 all summary` — session up? | Verify `send-community extended` on eBGP VPNv4 session |
| Labels not exchanged (Option B) | `show ip bgp vpnv4 all labels` | Ensure `mpls bgp forwarding` on inter-AS interface |
| Remote PE loopback unreachable (Option C) | `show ip bgp 8.8.8.8` — label present? | Verify `send-label` on BGP IPv4 session between ASBRs |
| VPNv4 next-hop unresolvable (Option C) | `show ip bgp vpnv4 all` — NH 8.8.8.8 valid? | Ensure labeled unicast route for 8.8.8.8 is in FIB |
| 3 labels expected but only 2 seen | `show mpls forwarding-table` on PE | Verify BGP-LU label is being pushed (recursive resolution) |
| Option A: routes in VRF but no end-to-end | `show ip route vrf CUSTOMER-A` on ASBR | Check eBGP VRF session between ASBRs is up |
| RT filtering too aggressive | `show ip bgp vpnv4 all` on ASBR — routes missing? | Check extcommunity-list includes all required RTs |
| `next-hop-unchanged` not working | VPNv4 routes have RR as NH instead of PE | Must be configured ONLY on RR-to-RR eBGP VPNv4 session |

---

## Key Commands Reference

```
! General verification:
show ip bgp vpnv4 all summary
show ip bgp vpnv4 all
show ip bgp vpnv4 all labels
show ip bgp vpnv4 vrf <name> <prefix>
show mpls forwarding-table vrf <name> [prefix] [detail]

! Option B specific:
show ip bgp vpnv4 all neighbors <ASBR-peer> advertised-routes
show ip bgp vpnv4 all neighbors <ASBR-peer> received-routes
show mpls forwarding-table labels <label>

! Option C specific:
show ip bgp <PE-loopback> — verify labeled unicast route
show ip bgp labels — see labels for IPv4 prefixes
show mpls forwarding-table <PE-loopback>/32
show ip cef <PE-loopback> — verify recursive resolution with label stack

! Debugging:
debug ip bgp vpnv4 unicast updates
debug mpls packets
```

---

## Exam Tips (SPCOR 350-501)

1. **Know the 3 options cold** — exam loves scenario-based questions: "Customer needs VPN across two SPs, which option?"
2. **Label stack depth:** Option A = no labels at boundary, Option B = 1 VPN label at boundary, Option C = 2 labels at boundary (BGP-LU + VPN)
3. **ASBR role differs:** Option A = PE, Option B = VPNv4 router, Option C = labeled unicast router (thinnest)
4. **next-hop-self vs next-hop-unchanged:** critical for Option C — get these wrong and VPN routes are unresolvable
5. **RT filtering (Option B):** reduces memory on ASBR — important for scalability questions
6. **CsC vs Inter-AS:** CsC = one SP provides MPLS transit to another SP. Inter-AS = same customer VPN across AS boundaries. Different use cases.
7. **Real-world prevalence:** Option C is most common within large SPs. Option A at peering points. Option B = middle ground.
