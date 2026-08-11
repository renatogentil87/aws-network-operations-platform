# Lab 27: mLDP & P2MP TE — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 2 RRs, 6 CEs. Full MPLS core with LDP, mVPN-capable.
**Prerequisite:** Labs 3 and 13 complete (MPLS-TE tunnels operational, mVPN Profile 0 working with GRE/default MDT)

**End Goal:** Replace GRE-based MDT (Profile 0) with mLDP-based multicast transport (Profile 1) — eliminating the need for PIM in the core. Build P2MP LSPs for efficient multicast replication, configure mLDP FEC types, and compare with RSVP-signalled P2MP TE tunnels. By the end, you understand why modern SPs prefer mLDP over core PIM for scalable multicast delivery.

**⚠️ Platform Note:** mLDP requires IOS 15.1(3)S+ on Cisco 7200. Verify your image supports `mpls mldp` commands. P2MP TE requires RSVP-TE extensions that may have limited support — test availability before starting Section 4.

---

## Section 1: mLDP Fundamentals

### Task 1: Enable mLDP on the MPLS Core

1. On ALL P and PE routers (R2-R8, R13-R18): enable mLDP:
   ```
   mpls mldp
   ```
2. Verify LDP is already running (from Lab 1): `show mpls ldp neighbor`
3. Verify mLDP capability advertised: `show mpls mldp neighbors`
   - Each neighbor should show "mLDP capability" in the output
4. Verify: `show mpls mldp database` — empty initially (no P2MP trees yet)
5. **Key concept:** mLDP extends LDP with new FEC types for multicast — runs on the same LDP sessions
6. No new sessions needed — mLDP piggybacks on existing targeted/link LDP sessions

### Task 2: Understand mLDP FEC Types

1. **P2MP FEC (Type 6):** Point-to-Multipoint — one root, multiple leaves
   - Root = source PE, Leaves = receiver PEs
   - Identified by: Root address + Opaque value
2. **MP2MP FEC (Type 7):** Multipoint-to-Multipoint — any node can send/receive
   - Identified by: Root address + Opaque value
   - Builds upstream AND downstream trees
3. On R2: `show mpls mldp root` — shows this router as potential root
4. **Opaque value:** application-specific identifier (VPN ID, MDT group, etc.)
5. The opaque value lets multiple P2MP trees coexist with different identifiers on the same root
6. Document: which FEC type maps to which mVPN profile (P2MP → Profile 1, MP2MP → Profile 14)

### Task 3: Build a Static P2MP LSP (Manual Tree)

1. Create a P2MP tree rooted at R2 (2.2.2.2) with leaves at R8, R17, R18:
2. On R8: signal leaf membership:
   ```
   mpls mldp p2mp 2.2.2.2 100
   ```
   (Opaque value = 100, identifies this specific tree)
3. On R17: `mpls mldp p2mp 2.2.2.2 100`
4. On R18: `mpls mldp p2mp 2.2.2.2 100`
5. Verify on R2 (root): `show mpls mldp database`
   - P2MP tree with root 2.2.2.2, opaque 100, branches toward R8, R17, R18
6. Verify on P routers (R3, R5, R7): `show mpls mldp database`
   - Transit entries showing replication points in the tree
7. Verify: `show mpls mldp database detail` — label bindings at each hop
8. **Key observation:** the tree follows the IGP shortest path from root to each leaf — no PIM needed

### Task 4: Verify P2MP Label Forwarding

1. On R2: `show mpls forwarding labels <label>` — find the P2MP output label(s)
2. Traffic entering R2 with the P2MP label gets replicated toward all leaves
3. On transit P routers: `show mpls forwarding` — SWAP + replicate entries
4. Verify: a single input label maps to MULTIPLE output labels (one per downstream branch)
5. `show mpls mldp database summary` — count total trees, leaves, transit entries
6. **Efficiency:** mLDP replicates at optimal branch points (just like PIM RPT/SPT) but uses MPLS labels — no PIM state in core
7. Remove static P2MP entries: `no mpls mldp p2mp 2.2.2.2 100` on leaves

---

## Section 2: mLDP-Based mVPN (Profile 1)

### Task 5: Configure mVPN Profile 1 (In-Band Signaling)

1. On R2: configure VRF Customer_A for mLDP-based mVPN:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default mpls mldp 2.2.2.2
   ```
   (Root = R2's loopback, default MDT uses mLDP P2MP tree)
2. On R8: configure matching mVPN for Customer_A:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default mpls mldp 2.2.2.2
   ```
3. On R17, R18: same configuration (if they have Customer_A VRF)
4. Verify: `show ip multicast vrf Customer_A mpls mldp` — mLDP tree details
5. Verify: `show mpls mldp database` — P2MP tree auto-created for the MDT
6. **Key difference from Profile 0:** no GRE tunnel, no core PIM, no RP in global table needed

### Task 6: Verify Multicast Flow Over mLDP

1. On R1 (CE, source): start multicast stream to 239.1.1.1:
   ```
   interface Loopback1
    ip igmp join-group 239.1.1.1
   ```
   On R1: `ping 239.1.1.1 source 1.1.1.1 repeat 100`
2. On R9 (CE, receiver): join group 239.1.1.1:
   - On R8 (PE): `ip igmp join-group 239.1.1.1` on VRF interface toward R9
3. Verify: `show ip mroute vrf Customer_A 239.1.1.1` on R2 — (S,G) entry with mLDP upstream
4. Verify: `show ip mroute vrf Customer_A 239.1.1.1` on R8 — (S,G) entry with downstream interface
5. On P routers: `show mpls mldp database` — transit replication entries (NO PIM mroute state!)
6. **Profile 1 advantage:** P routers carry only MPLS labels — no (S,G) or (*,G) state
7. Verify: `show ip pim neighbor` on P routers — NO PIM neighbors (PIM removed from core)

### Task 7: In-Band Signaling for C-Multicast

1. In-band signaling means: customer multicast join/prune signals travel INSIDE the mLDP tree
2. When R9 joins 239.1.1.1 → R8 sends PIM Join inside the VRF → travels over mLDP P2MP to R2
3. Verify: `show ip pim vrf Customer_A neighbor` — PE-CE PIM sessions only (not PE-PE)
4. Verify: `show ip mroute vrf Customer_A count` — multicast counters incrementing
5. No BGP signaling needed for C-multicast routes (unlike Profile 6/7)
6. **Simplicity:** in-band signaling = PIM in VRF handles everything, mLDP just provides transport
7. Compare with Profile 0: Profile 0 also uses in-band signaling but over GRE → less efficient

### Task 8: Data MDT with mLDP

1. Configure a data MDT threshold for high-bandwidth streams:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt data mpls mldp 100
     mdt data threshold 50
   ```
   (Create data MDT when stream exceeds 50 kbps, max 100 data MDTs)
2. Generate high-bandwidth multicast from R1 (extended ping, large packets)
3. Verify: `show ip multicast vrf Customer_A mpls mldp` — data MDT created
4. Verify: `show mpls mldp database` — new P2MP tree (data MDT) with only interested receivers
5. **Benefit:** data MDT = separate optimized tree for high-bandwidth → only receivers pull the traffic
6. Default MDT carries signaling + low-bandwidth; data MDT carries heavy streams
7. Remove high-bandwidth source — verify data MDT eventually torn down

---

## Section 3: Comparison — Profile 0 (GRE) vs Profile 1 (mLDP)

### Task 9: Profile 0 Recap (GRE MDT)

1. Revert R2 to Profile 0 for comparison:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default 232.1.1.1
   ```
2. Verify: `show ip pim neighbor` on P routers — PIM neighbors appear (core PIM required!)
3. Verify: `show ip mroute 232.1.1.1` on P routers — GRE tunnel MDT state in global table
4. Count: how many (S,G) entries on each P router? (One per PE in the MDT group)
5. **Profile 0 scaling problem:** 100 VRFs × 4 PEs = 400 (S,G) entries on every P router
6. Revert back to Profile 1 (mLDP) after comparison

### Task 10: Profile 1 Scaling Advantage

1. With Profile 1 active: `show ip mroute count` on P routers — ZERO multicast routes in global table
2. `show mpls mldp database summary` — only mLDP label entries (much more scalable)
3. **Comparison table:**

| Feature | Profile 0 (GRE) | Profile 1 (mLDP) |
|---------|-----------------|-------------------|
| Core PIM required | Yes | No |
| P router state | (S,G) per PE per VRF | MPLS labels only |
| Encapsulation | GRE (IP overhead) | MPLS (label overhead) |
| RP in core | Required (for SSM: no) | Not needed |
| Scalability | Limited by mroute state | Scales with MPLS label space |
| Data MDT | GRE-based | mLDP P2MP tree |

4. Verify encapsulation: capture on a P router link — Profile 1 shows MPLS labels, no GRE header
5. **Bandwidth efficiency:** MPLS label = 4 bytes, GRE header = 24 bytes overhead per packet
6. Document: when would you still use Profile 0? (Answer: legacy routers without mLDP support)

---

## Section 4: P2MP TE Tunnels (RSVP Signaled)

### Task 11: Configure P2MP TE Tunnel

1. **Prerequisite:** RSVP-TE running on core (from Lab 3)
2. On R2 (headend): create a P2MP TE tunnel:
   ```
   interface Tunnel100
    ip unnumbered Loopback0
    tunnel mode mpls traffic-eng point-to-multipoint
    tunnel mpls traffic-eng path-option 1 dynamic
   ```
3. Add destinations (tail-ends):
   ```
   interface Tunnel100
    tunnel destination list mpls traffic-eng name MCAST-RECEIVERS
   !
   mpls traffic-eng destination list name MCAST-RECEIVERS
    ip 8.8.8.8 path-option 1 dynamic
    ip 17.17.17.17 path-option 1 dynamic
    ip 18.18.18.18 path-option 1 dynamic
   ```
4. Verify: `show mpls traffic-eng tunnels tunnel 100` — P2MP tunnel UP
5. Verify: `show mpls traffic-eng tunnels tunnel 100 p2mp` — all destinations signaled
6. **P2MP TE vs mLDP:** P2MP TE uses RSVP signaling, gives you bandwidth reservation per branch

### Task 12: P2MP TE with Explicit Paths

1. Define explicit paths for each destination:
   ```
   ip explicit-path name TO-R8-VIA-R5
    next-address 5.5.5.5
    next-address 7.7.7.7
    next-address 8.8.8.8
   ```
2. Apply explicit path to destination:
   ```
   mpls traffic-eng destination list name MCAST-RECEIVERS
    ip 8.8.8.8 path-option 1 explicit name TO-R8-VIA-R5
   ```
3. Verify: `show mpls traffic-eng tunnels tunnel 100 detail` — path follows explicit route
4. Verify: `show mpls traffic-eng topology p2mp` — P2MP tree topology
5. **Use case:** pin multicast traffic to specific links for capacity planning
6. Verify: `show rsvp reservation` — bandwidth reserved on each link in the tree
7. **Comparison with mLDP:** mLDP follows IGP; P2MP TE can be constrained (bandwidth, affinity)

### Task 13: P2MP TE for mVPN (Profile 7 Concept)

1. Concept: use P2MP TE tunnel as MDT transport for mVPN:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default mpls traffic-eng p2mp Tunnel100
   ```
2. **Note:** full Profile 7 (RSVP-TE P2MP with BGP C-multicast signaling) may not be supported on IOS 15.2/7200
3. If supported: verify multicast traffic flows over the P2MP TE tunnel
4. If not supported: document the concept and configuration for IOS-XR:
   ```
   ! IOS-XR equivalent:
   multicast-routing
    vrf Customer_A
     address-family ipv4
      mdt source Loopback0
      mdt default mldp p2mp
      mdt data p2mp-te 100
   ```
5. **Profile 7 advantage:** traffic-engineered multicast with bandwidth guarantees
6. **Tradeoff:** RSVP state on all transit routers (same scalability concern as P2P TE tunnels)

---

## Section 5: mLDP Advanced Features

### Task 14: MP2MP Trees (Multipoint-to-Multipoint)

1. Configure an MP2MP tree rooted at R3 (3.3.3.3):
   ```
   mpls mldp mp2mp 3.3.3.3 200
   ```
   On R2, R8, R17, R18 (all participants send AND receive)
2. Verify: `show mpls mldp database` — MP2MP FEC type entries
3. **Key difference from P2MP:** any leaf can send traffic UP toward root, root replicates DOWN to other leaves
4. With P2MP: only root sends, leaves receive
5. With MP2MP: bidirectional — any node can be source (without building separate tree)
6. Verify: `show mpls mldp database detail` — upstream AND downstream labels allocated
7. **Use case:** MP2MP for VRFs where any site can be multicast source (VPLS-like multicast)

### Task 15: mLDP Recursive FEC (Nested mLDP)

1. Concept: mLDP FEC can reference another FEC — creating hierarchical trees
2. Use case: inter-AS mVPN where each AS builds its own mLDP tree, stitched at AS boundary
3. On R5 (ASBR-equivalent): configure recursive FEC:
   ```
   mpls mldp recursive-fec
   ```
4. Verify: `show mpls mldp database recursive` — nested tree information
5. **Note:** this is primarily a concept on IOS 15.2 — full implementation requires IOS-XR
6. Document: how recursive FEC enables multi-domain multicast without core PIM

### Task 16: mLDP MoFRR (Multicast Only Fast Reroute)

1. Enable MoFRR for mLDP:
   ```
   mpls mldp mofrr
   ```
2. **Concept:** primary AND backup mLDP paths computed simultaneously
   - Both paths carry traffic — receiver accepts from primary, discards backup
   - On primary failure: instant switchover to backup (already receiving)
3. Verify: `show mpls mldp database mofrr` — primary and backup paths listed
4. Verify: `show mpls mldp mofrr summary` — MoFRR status
5. Simulate link failure on primary path — verify instant switchover (sub-second)
6. **Benefit:** zero multicast packet loss during link failures (live-live model)
7. **Note:** verify MoFRR support on your IOS version: `show mpls mldp capabilities`

---

## CCIE+ Challenges

### Challenge 1: mLDP with Partitioned MDT

1. Configure partitioned MDT (each PE builds its own P2MP tree to receivers):
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default mpls mldp p2mp
     mdt partitioned mldp p2mp
   ```
2. Verify: each PE creates a separate P2MP tree rooted at itself
3. Receivers join only the trees they need (not a full mesh of trees)
4. **Scalability:** with 100 PEs, full mesh = 100 trees per receiver. Partitioned = only trees with active sources
5. Compare: `show mpls mldp database summary` with and without partitioned MDT
6. Document: traffic flow difference between partitioned and non-partitioned MDT

### Challenge 2: mLDP with BGP Auto-Discovery

1. Use BGP auto-discovery (AD) to signal mVPN membership:
   ```
   router bgp 64512
    address-family ipv4 mdt
     neighbor 3.3.3.3 activate
   ```
2. PEs advertise MDT membership via BGP → peers auto-join the mLDP tree
3. Verify: `show ip bgp ipv4 mdt all` — MDT routes advertised
4. **Advantage:** PEs don't need static MDT configuration — BGP handles discovery
5. Combine with RT-constraint: only relevant PEs receive MDT advertisements

### Challenge 3: Dual-Root P2MP Redundancy

1. Configure two P2MP trees with different roots for the same VRF:
   - Primary: rooted at R2 (2.2.2.2)
   - Backup: rooted at R8 (8.8.8.8)
2. Verify: both trees built simultaneously
3. Shut R2's loopback — verify traffic switches to R8's tree
4. Bring R2 back — verify primary tree re-established
5. **Design:** root diversity ensures no single PE failure kills the entire MDT

### Challenge 4: mLDP with SR-MPLS (Segment Routing Underlay)

1. Concept: mLDP tree follows SR-labeled paths instead of LDP
2. Enable SR and mLDP simultaneously:
   - SR for unicast (prefix-SIDs)
   - mLDP for multicast (builds trees using SR-resolved next-hops)
3. Verify: mLDP tree next-hops resolved via SR labels in FIB
4. **Modern architecture:** SR for unicast + mLDP for multicast = no LDP needed at all
5. Document: interaction between mLDP and SR in the LFIB

---

## Final Validation

By the end of this lab, your network has:

- [ ] mLDP enabled on all core routers (extends existing LDP sessions)
- [ ] P2MP FEC types understood (P2MP vs MP2MP)
- [ ] Static P2MP tree built and verified (root + leaves)
- [ ] mVPN Profile 1 operational (mLDP replaces GRE MDT)
- [ ] In-band signaling working for C-multicast joins over mLDP
- [ ] Data MDT with mLDP creating per-stream optimized trees
- [ ] Core PIM completely removed — P routers carry only MPLS state
- [ ] Profile 0 vs Profile 1 comparison documented with scaling analysis
- [ ] P2MP TE tunnel signaled via RSVP (bandwidth-aware multicast tree)
- [ ] MP2MP tree built for bidirectional multicast
- [ ] mLDP MoFRR providing hitless multicast failover
- [ ] (CCIE+) Partitioned MDT reducing unnecessary tree membership
- [ ] (CCIE+) BGP auto-discovery for dynamic MDT signaling
- [ ] (CCIE+) Dual-root redundancy for MDT resilience
