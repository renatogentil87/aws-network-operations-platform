# Lab 16: Segment Routing (SR-MPLS & SR-TE) — Workbook

**Platform:** EVE-NG on AWS c5.metal
**Images Required:** IOS-XRv 9000 (7.x+), CSR1000v (IOS-XE 17.x+)
**Topology:** 10 routers — custom SR topology (see below)

**⚠️ EVE-NG REQUIRED:** This lab cannot run on GNS3/Cisco 7200. Segment Routing requires IOS-XR or IOS-XE 16.x+. Deploy on your c5.metal EVE-NG instance.

**End Goal:** A fully segment-routed SP core with prefix-SIDs, adjacency-SIDs, TI-LFA for sub-50ms protection, and SR-TE policies replacing RSVP-TE tunnels — all without per-tunnel state on transit routers. By the end, you understand why the industry is migrating from RSVP-TE to SR-TE.

---

## EVE-NG Topology — 10 Routers

```
                    ┌─────────────────────────────────────────┐
                    │              SR CORE (IS-IS)             │
                    │                                         │
    CE1 ──── PE1 ──── P1 ──── P2 ──── P3 ──── PE3 ──── CE3  │
              │       │         │       │       │             │
              │       │         P4      │       │             │
              │       │         │       │       │             │
    CE2 ──── PE2 ────────────── P5 ────────── PE4 ──── CE4   │
                    │                                         │
                    └─────────────────────────────────────────┘
```

### Router Assignments

| Router | Role | Image | Loopback | Prefix-SID |
|---|---|---|---|---|
| PE1 | Provider Edge | IOS-XRv | 10.0.0.1/32 | 16001 |
| PE2 | Provider Edge | IOS-XRv | 10.0.0.2/32 | 16002 |
| PE3 | Provider Edge | IOS-XRv | 10.0.0.3/32 | 16003 |
| PE4 | Provider Edge | IOS-XRv | 10.0.0.4/32 | 16004 |
| P1 | Core | IOS-XRv | 10.0.0.11/32 | 16011 |
| P2 | Core | IOS-XRv | 10.0.0.12/32 | 16012 |
| P3 | Core | IOS-XRv | 10.0.0.13/32 | 16013 |
| P4 | Core | IOS-XRv | 10.0.0.14/32 | 16014 |
| P5 | Core | IOS-XRv | 10.0.0.15/32 | 16015 |
| CE1 | Customer Edge | CSR1000v or XRv | 10.0.0.101/32 | — |
| CE2 | Customer Edge | CSR1000v or XRv | 10.0.0.102/32 | — |
| CE3 | Customer Edge | CSR1000v or XRv | 10.0.0.103/32 | — |
| CE4 | Customer Edge | CSR1000v or XRv | 10.0.0.104/32 | — |

### Link Addressing (Point-to-Point /30s)

| Link | Subnet |
|---|---|
| PE1 — P1 | 10.1.0.0/30 |
| PE1 — PE2 | 10.1.0.4/30 |
| P1 — P2 | 10.1.0.8/30 |
| P1 — P4 | 10.1.0.12/30 |
| P2 — P3 | 10.1.0.16/30 |
| P2 — P4 | 10.1.0.20/30 |
| P3 — PE3 | 10.1.0.24/30 |
| P3 — P5 | 10.1.0.28/30 |
| P4 — P5 | 10.1.0.32/30 |
| PE2 — P5 | 10.1.0.36/30 |
| PE3 — PE4 | 10.1.0.40/30 |
| PE4 — P5 | 10.1.0.44/30 |
| PE1 — CE1 | 192.168.1.0/30 |
| PE2 — CE2 | 192.168.2.0/30 |
| PE3 — CE3 | 192.168.3.0/30 |
| PE4 — CE4 | 192.168.4.0/30 |

---

## Section 1: SR-MPLS Foundation (Prefix-SIDs)

### Task 1: Enable Segment Routing with IS-IS

1. On ALL core routers (PE1-PE4, P1-P5): configure IS-IS with SR:
   ```
   router isis CORE
    is-type level-2-only
    net 49.0001.0100.0000.0001.00
    address-family ipv4 unicast
     metric-style wide
     segment-routing mpls
    interface Loopback0
     passive
     address-family ipv4 unicast
      prefix-sid index 1        ← (unique per router: PE1=1, PE2=2, P1=11, etc.)
   ```
2. On ALL core interfaces: enable IS-IS
3. Set SRGB (Segment Routing Global Block) — same range on all routers:
   - `segment-routing global-block 16000 23999`
4. Verify: `show isis segment-routing label table` — all prefix-SIDs present
5. Verify: `show mpls forwarding` — labels 16001-16015 installed in LFIB
6. Verify: `ping 10.0.0.3 source 10.0.0.1` — works via SR labels (no LDP needed!)

### Task 2: Understand Prefix-SID vs LDP

1. **Key difference:** prefix-SID = globally significant label. LDP label = locally significant.
2. On PE1: `show mpls forwarding labels 16003` — one entry, consistent on EVERY router
3. On P1: `show mpls forwarding labels 16003` — same label 16003, action SWAP or POP
4. Compare with LDP: `show mpls ldp bindings 10.0.0.3/32` — each router has DIFFERENT local label
5. **SR advantage:** label for "reach PE3" is 16003 EVERYWHERE — simplifies debugging, enables source routing
6. Remove LDP from the core: `no mpls ldp` on all interfaces — SR alone provides transport
7. Verify: all connectivity still works via SR-MPLS (no LDP needed)

### Task 3: Adjacency-SIDs

1. On PE1: `show isis adjacency detail` — note adjacency-SIDs per neighbor
2. Adjacency-SIDs are locally significant (like LDP labels) — identify a SPECIFIC link
3. On PE1: `show isis segment-routing adjacency-sid` — list all adj-SIDs
4. Use case: force traffic to a specific link (not just "reach PE3 via any path")
5. A label stack of [adj-SID-to-P1, adj-SID-P1-to-P2, 16003] forces: PE1→P1→P2→PE3
6. This is **source routing** — headend encodes the entire path in the label stack

---

## Section 2: TI-LFA (Topology Independent Loop-Free Alternate)

### Task 4: Enable TI-LFA

1. On ALL routers: under IS-IS interface configuration:
   ```
   interface GigabitEthernet0/0/0/0
    address-family ipv4 unicast
     fast-reroute per-prefix
     fast-reroute per-prefix ti-lfa
   ```
2. Enable on ALL core interfaces
3. Verify: `show isis fast-reroute summary` — TI-LFA computing backup paths
4. Verify: `show isis fast-reroute 10.0.0.3/32 detail` — backup path pre-computed

### Task 5: Verify TI-LFA Protection

1. On PE1: `show cef 10.0.0.3/32` — primary AND backup path installed in CEF
2. Start continuous ping from CE1 to CE3 (10000 packets, timeout 1)
3. Shut the link PE1→P1 (primary path to PE3)
4. Count packet loss — target: 0-1 packets (sub-50ms, TI-LFA switches in hardware)
5. Bring link back — verify primary path restores
6. Compare with RSVP-TE FRR:
   - RSVP-TE FRR: requires pre-signalling backup tunnels on transit routers (state everywhere)
   - TI-LFA: computed locally, no state on other routers, protects EVERY prefix automatically
7. **This is why SR replaces RSVP-TE:** TI-LFA gives you FRR-equivalent protection with ZERO configuration on transit routers

### Task 6: TI-LFA with Node Protection

1. TI-LFA default: link protection (bypass the failed link)
2. Enable node protection: fast-reroute computes path around entire failed node
3. Shut ALL interfaces on P1 (simulate node failure)
4. Verify: traffic from PE1 to PE3 continues flowing via alternate path
5. Packet loss: 0-2 packets (same as RSVP-TE node protection, but no backup tunnel config)
6. Verify: `show cef 10.0.0.3/32` during failure — backup label stack used

---

## Section 3: SR-TE Policies (Replace RSVP-TE Tunnels)

### Task 7: Create an SR-TE Policy (Explicit Path)

1. On PE1: create an SR-TE policy to PE3:
   ```
   segment-routing
    traffic-eng
     policy PE1-TO-PE3-VIA-P2
      color 100 end-point ipv4 10.0.0.3
      candidate-paths
       preference 100
        explicit segment-list VIA-P2
    segment-lists
     segment-list VIA-P2
      index 10 mpls label 16012   ← P2 prefix-SID
      index 20 mpls label 16003   ← PE3 prefix-SID
   ```
2. Verify: `show segment-routing traffic-eng policy` — policy UP
3. Verify: `show segment-routing traffic-eng forwarding policy` — label stack imposed
4. The label stack [16012, 16003] tells the network: go to P2, then go to PE3
5. **No RSVP state on transit routers** — P1 just forwards based on top label (16012)

### Task 8: Dynamic Path (CSPF Equivalent)

1. Configure a dynamic SR-TE policy:
   ```
   segment-routing
    traffic-eng
     policy PE1-TO-PE3-DYNAMIC
      color 200 end-point ipv4 10.0.0.3
      candidate-paths
       preference 100
        dynamic
         metric type igp
   ```
2. Verify: policy computes the shortest IGP path and installs label stack
3. Verify: `show segment-routing traffic-eng policy detail` — computed path visible
4. Change IGP metrics on a link — verify policy recomputes automatically
5. Compare with RSVP-TE dynamic tunnel: same result, no RSVP signalling

### Task 9: SR-TE with Constraints (Affinity)

1. On core interfaces: assign affinity (same concept as RSVP-TE attribute-flags):
   ```
   segment-routing
    traffic-eng
     interface GigabitEthernet0/0/0/0
      affinity
       color RED
   ```
2. Define affinity-map: `affinity-map RED bit-position 0`
3. Create a policy that avoids RED links:
   ```
   policy AVOID-RED
    candidate-paths
     preference 100
      dynamic
       metric type igp
      constraints
       affinity
        exclude-any RED
   ```
4. Verify: policy path avoids all RED-colored links
5. Same traffic engineering capability as RSVP-TE affinity — zero state on transit routers

---

## Section 4: SR-TE for VPN Traffic

### Task 10: Steer VPN Traffic into SR-TE Policy

1. Configure L3VPN on PE1 and PE3 (same as RSVP-TE VPN from Lab 3):
   - VRF, eBGP to CE, vpnv4 between PEs
2. Use SR-TE policy coloring to steer VPN traffic:
   ```
   router bgp 64512
    vrf CUSTOMER_A
     address-family ipv4 unicast
      network ...
    neighbor 10.0.0.3
     address-family vpnv4 unicast
      route-policy SET-COLOR out
   
   route-policy SET-COLOR
    set extcommunity color 100
   end-policy
   ```
3. BGP next-hop 10.0.0.3 + color 100 → maps to SR-TE policy "color 100 end-point 10.0.0.3"
4. Verify: `show cef vrf CUSTOMER_A <prefix>` — traffic uses SR-TE policy
5. Verify: traceroute from CE1 to CE3 — follows SR-TE policy path
6. **This replaces autoroute announce from RSVP-TE** — color-based steering is more flexible

### Task 11: Per-VRF Differentiated SR-TE

1. Customer_A (premium): color 100 → explicit low-latency path
2. Customer_B (best-effort): color 200 → shortest IGP path
3. Configure different policies for each color
4. Verify: Customer_A traffic follows the engineered path
5. Verify: Customer_B traffic follows IGP shortest path
6. **SP model:** different service tiers mapped to different SR-TE policies via BGP color

---

## Section 5: SR and LDP Interworking (Migration)

### Task 12: SR-LDP Coexistence

1. Enable BOTH SR and LDP on the core (ships-in-the-night):
   - SR labels (16000+) and LDP labels coexist in LFIB
2. On PE1: `show mpls forwarding` — both SR labels and LDP labels installed
3. Traffic uses SR labels (preferred) when available, falls back to LDP
4. Verify: shut SR on one router — traffic falls back to LDP seamlessly
5. Bring SR back — traffic returns to SR labels
6. **Migration path:** enable SR alongside LDP, migrate traffic gradually, remove LDP last

### Task 13: Mapping Server (for LDP-Only Islands)

1. Scenario: P4 can't run SR (legacy router)
2. Configure a mapping server on P1:
   - `segment-routing mapping-server prefix-sid-map address-family ipv4`
   - `10.0.0.14/32 16014` (advertise P4's prefix-SID on its behalf)
3. SR routers can now reach P4 via SR labels (mapping server translates)
4. Verify: `show segment-routing mapping-server prefix-sid-map` — P4 mapped
5. This allows gradual migration — not all routers need SR simultaneously

---

## CCIE+ Challenges

### Challenge 1: On-Demand Next-Hop (ODN)

1. PE automatically creates SR-TE policy when BGP next-hop + color appears:
   ```
   segment-routing traffic-eng
    on-demand color 100
     dynamic metric type latency
   ```
2. No pre-configured policy needed — SR-TE policy created dynamically per BGP route color
3. Verify: add a VRF route with color 100 — SR-TE policy auto-created
4. Remove the route — policy auto-deleted
5. **Scalability:** with 1000 VRFs, you don't pre-configure 1000 policies

### Challenge 2: PCE (Path Computation Element) Centralized Control

1. Deploy a PCE server (if image supports it) or configure stateful PCE on one router
2. SR-TE policies delegated to PCE for centralized path computation
3. PCE has global network view — computes optimal paths across domains
4. Verify: `show segment-routing traffic-eng policy` — "delegated" to PCE
5. **Modern SP architecture:** PCE controller + SR-TE = SDN-like control with distributed forwarding

### Challenge 3: Flex-Algo (Flexible Algorithm)

1. Define custom algorithms for different traffic types:
   - Algo 128: minimize latency
   - Algo 129: maximize bandwidth
2. On selected interfaces: advertise metric for each algorithm
3. Prefix-SIDs are per-algorithm: `prefix-sid algorithm 128 index 101`
4. Traffic steered by algorithm choice — no explicit path needed
5. **Next-generation TE:** intent-based ("low latency" or "high bandwidth") without explicit hop-by-hop paths

---

## Final Validation

By the end of this lab, your network has:

- [ ] IS-IS with segment-routing enabled on all core routers
- [ ] Prefix-SIDs globally consistent (same label everywhere for same destination)
- [ ] Adjacency-SIDs for per-link traffic steering
- [ ] LDP removed — pure SR-MPLS transport
- [ ] TI-LFA providing sub-50ms protection for ALL prefixes (no backup tunnel config)
- [ ] Node protection via TI-LFA (entire router failure survived)
- [ ] SR-TE explicit policy replacing RSVP-TE explicit-path tunnel
- [ ] SR-TE dynamic policy replacing RSVP-TE dynamic tunnel
- [ ] SR-TE affinity constraints (same as RSVP-TE link coloring, zero transit state)
- [ ] VPN traffic steered via SR-TE policy using BGP color community
- [ ] Per-VRF/per-customer differentiated SR-TE paths
- [ ] SR-LDP interworking for migration scenarios
- [ ] (CCIE+) On-Demand Next-Hop (ODN) for auto-created policies
- [ ] (CCIE+) PCE centralized path computation concept
- [ ] (CCIE+) Flex-Algo for intent-based traffic engineering
