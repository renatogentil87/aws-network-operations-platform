# Lab 29: mVPN Advanced Profiles — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 2 RRs, 6 CEs. Full MPLS core with LDP, mVPN baseline.
**Prerequisite:** Lab 13 complete (mVPN Profile 0 working with GRE/default MDT, PIM operational in core)

**End Goal:** Implement advanced mVPN profiles that decouple C-multicast signaling from transport — using BGP for auto-discovery and C-multicast routing, mLDP or RSVP-TE P2MP for data transport, and partitioned MDTs for scale. By the end, you understand Profiles 6, 7, and related concepts (S-PMSI, I-PMSI, BGP AD) that modern SPs deploy for IPTV and enterprise multicast at scale.

**⚠️ Platform Note:** Advanced mVPN profiles (6, 7) require IOS 15.2(1)S+ or IOS-XR. Some features may not be fully available on Cisco 7200. Where hardware limitations exist, configuration syntax is provided for reference with IOS-XR equivalents noted.

---

## Section 1: mVPN Architecture Review — PMSI and BGP AD

### Task 1: Understand I-PMSI and S-PMSI

1. **I-PMSI (Inclusive PMSI):** Default multicast tree — ALL PEs in the VPN join
   - Carries signaling + low-bandwidth multicast
   - Every PE receives ALL traffic (even if no local receivers)
   - Profile 0 example: MDT default group (232.1.1.1)
2. **S-PMSI (Selective PMSI):** Per-source/group tree — only interested PEs join
   - Created when traffic exceeds threshold or matches specific (S,G)
   - Only PEs with active receivers join → bandwidth efficient
   - Profile 0 example: MDT data group
3. On R2: `show ip multicast vrf Customer_A mpls mldp` — identify I-PMSI
4. Verify: ALL PEs in Customer_A VPN are members of the I-PMSI (even without receivers)
5. **Scaling problem:** with 100 PEs in a VPN, I-PMSI sends ALL multicast to ALL 100 PEs
6. S-PMSI solution: only 3 PEs with receivers join the S-PMSI → 97 PEs don't receive unwanted traffic
7. Document: I-PMSI = always-on (signaling), S-PMSI = on-demand (data)

### Task 2: BGP Auto-Discovery (AD) for mVPN

1. BGP AD replaces static MDT configuration — PEs discover each other dynamically
2. On R2: enable mVPN address-family (ipv4 mdt or ipv4 mvpn):
   ```
   router bgp 64512
    address-family ipv4 mvpn
     neighbor 3.3.3.3 activate
     neighbor 7.7.7.7 activate
   ```
3. On R3 (RR): configure mvpn address-family and reflect to all PEs:
   ```
   router bgp 64512
    address-family ipv4 mvpn
     neighbor 2.2.2.2 activate
     neighbor 2.2.2.2 route-reflector-client
     neighbor 8.8.8.8 activate
     neighbor 8.8.8.8 route-reflector-client
   ```
4. Repeat on R7 (RR) and all PEs (R8, R17, R18)
5. Verify: `show ip bgp ipv4 mvpn all` — mVPN routes advertised
6. **BGP AD Route Types:**
   - Type 1: Intra-AS I-PMSI AD (advertises PE participation in VPN)
   - Type 2: Inter-AS I-PMSI AD
   - Type 3: S-PMSI AD (signals selective tree for specific S,G)
   - Type 4: Leaf AD (receiver PE responds to S-PMSI AD)
   - Type 5: Source Active AD (signals active multicast sources)
7. Verify: `show ip bgp ipv4 mvpn all route-type 1` — Type 1 routes from all PEs in VPN

### Task 3: BGP AD Type 1 — I-PMSI Auto-Discovery

1. On R2: verify Type 1 route is originated:
   ```
   show ip bgp ipv4 mvpn vrf Customer_A route-type 1
   ```
   - Contains: RD, Originator (R2), PMSI Tunnel Attribute
2. On R8: verify Type 1 received from R2 (via RR):
   ```
   show ip bgp ipv4 mvpn all
   ```
3. The PMSI Tunnel Attribute in Type 1 tells receivers HOW to join the I-PMSI:
   - Tunnel type 2 = mLDP P2MP
   - Tunnel type 1 = RSVP-TE P2MP
   - Tunnel type 6 = PIM (SSM/ASM tree)
4. Verify: decode the PMSI attribute — `show ip bgp ipv4 mvpn all detail`
5. **Benefit:** PEs automatically discover each other AND the tunnel technology — no static config
6. New PE added to VPN → BGP AD propagates, existing PEs discover it automatically

---

## Section 2: Profile 6 — PIM/mLDP with BGP C-Multicast Signaling

### Task 4: Configure Profile 6 Concept

1. **Profile 6 architecture:**
   - Transport: mLDP P2MP (same as Profile 1)
   - C-multicast signaling: BGP (NOT PIM between PEs)
   - I-PMSI: mLDP P2MP tree (all PEs join)
   - S-PMSI: separate mLDP tree per (S,G)
2. On R2: configure VRF for Profile 6:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default mpls mldp 2.2.2.2
     mdt overlay use-bgp
   ```
3. On R8, R17, R18: matching configuration (mdt default points to same root)
4. Verify: `show ip multicast vrf Customer_A mpls mldp` — mLDP tree active
5. **Key "use-bgp":** C-multicast (customer) join/leave signals travel via BGP, not PIM between PEs
6. Verify: `show ip bgp ipv4 mvpn vrf Customer_A` — BGP C-multicast routes present

### Task 5: BGP C-Multicast Signaling (Type 5 and Type 7 Routes)

1. On R1 (CE source): start multicast to 239.1.1.1:
   - Configure R1 as source: `interface Loopback1` / `ip igmp join-group 239.1.1.1`
2. On R2 (source PE): verify BGP Type 5 (Source Active) route generated:
   ```
   show ip bgp ipv4 mvpn vrf Customer_A route-type 5
   ```
   - Announces: "I have an active source for (S,G) in this VPN"
3. On R9 (CE receiver): join 239.1.1.1 (via IGMP to R8)
4. On R8 (receiver PE): verify BGP Type 7 (C-multicast Join) route generated:
   ```
   show ip bgp ipv4 mvpn vrf Customer_A route-type 7
   ```
   - Announces: "I have a receiver for this (S,G) — please send traffic"
5. Verify: R2 receives Type 7 from R8 → starts sending multicast toward R8
6. **Advantage over PIM signaling:** BGP scales better (RR distributes), supports RT-constraint, familiar operational model
7. Remove receiver on R9 — verify Type 7 withdrawn, traffic stops

### Task 6: S-PMSI with BGP (Selective Tree)

1. Configure S-PMSI for high-bandwidth streams:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt data mpls mldp 100
     mdt data threshold 10
   ```
2. Generate high-bandwidth multicast from R1 (exceeds 10 kbps threshold)
3. On R2: verify BGP Type 3 (S-PMSI AD) route generated:
   ```
   show ip bgp ipv4 mvpn vrf Customer_A route-type 3
   ```
   - Announces: "I'm creating a selective tree for this (S,G)"
4. On R8 (receiver PE): verify BGP Type 4 (Leaf AD) response:
   ```
   show ip bgp ipv4 mvpn vrf Customer_A route-type 4
   ```
   - Responds: "I want to join this selective tree"
5. Verify: `show mpls mldp database` — new S-PMSI tree (separate from I-PMSI)
6. **Result:** high-bandwidth stream moved from I-PMSI (hits all PEs) to S-PMSI (only receiver PEs)
7. On R17 (no receiver): verify it does NOT receive the high-bandwidth stream after S-PMSI activation

---

## Section 3: Profile 7 — PIM/RSVP-TE P2MP

### Task 7: Profile 7 Architecture

1. **Profile 7:**
   - Transport: RSVP-TE P2MP tunnels (bandwidth-reserved multicast trees)
   - C-multicast signaling: BGP
   - I-PMSI: RSVP-TE P2MP tunnel from each source PE
   - S-PMSI: separate RSVP-TE P2MP tunnel per (S,G) or (S,G) group
2. **Advantage over mLDP:** bandwidth reservation on each link of the tree
3. **Disadvantage:** RSVP state on all transit routers (same as P2P TE scalability concern)
4. **Use case:** IPTV head-end with guaranteed bandwidth per channel
5. Document the profile comparison:

| Feature | Profile 1 (mLDP) | Profile 6 (mLDP+BGP) | Profile 7 (RSVP P2MP+BGP) |
|---------|-------------------|----------------------|---------------------------|
| Transport | mLDP P2MP | mLDP P2MP | RSVP-TE P2MP |
| C-mcast signaling | In-band (PIM in VRF) | BGP | BGP |
| Bandwidth control | No | No | Yes (RSVP reservation) |
| Core state | mLDP labels | mLDP labels | RSVP soft-state per tree |
| Auto-discovery | Static | BGP AD | BGP AD |

### Task 8: Configure RSVP-TE P2MP for mVPN (Concept)

1. **Note:** Full Profile 7 implementation requires IOS-XR or IOS 15.4+. Configure as far as supported:
2. On R2: enable P2MP RSVP capability:
   ```
   mpls traffic-eng tunnels
   mpls traffic-eng multicast-intact
   ```
3. Create P2MP TE tunnel for I-PMSI:
   ```
   interface Tunnel200
    ip unnumbered Loopback0
    tunnel mode mpls traffic-eng point-to-multipoint
    tunnel destination list mpls traffic-eng name CUSTOMER-A-MDT
   ```
4. Associate with VRF (IOS-XR syntax for reference):
   ```
   ! IOS-XR:
   multicast-routing
    vrf Customer_A
     address-family ipv4
      mdt source Loopback0
      mdt default mldp p2mp
      mdt data p2mp-te 100 threshold 10
   ```
5. If supported on IOS 15.2: `mdt default mpls traffic-eng p2mp Tunnel200`
6. Verify: P2MP TE tunnel UP with destinations matching VPN membership
7. **Fallback:** if not supported, document the concept and verify with Profile 6 instead

### Task 9: Bandwidth Reservation per Multicast Tree

1. On P2MP TE tunnel: reserve bandwidth per destination:
   ```
   mpls traffic-eng destination list name CUSTOMER-A-MDT
    ip 8.8.8.8 path-option 1 dynamic bandwidth 10000
    ip 17.17.17.17 path-option 1 dynamic bandwidth 5000
   ```
2. Verify: `show mpls traffic-eng tunnels tunnel 200` — bandwidth reserved
3. Verify: `show rsvp reservation` on transit routers — bandwidth allocated per branch
4. **IPTV example:** 500 Mbps reserved for multicast tree carrying 100 SD channels
5. If tree bandwidth exceeds link capacity: RSVP signals failure → tree rerouted around congested link
6. **Profile 7 strength:** admission control prevents multicast from overloading links
7. Compare with mLDP: mLDP has NO admission control — relies on QoS policing instead

---

## Section 4: Data MDT and Partitioned MDT

### Task 10: Data MDT Deep Dive

1. **Data MDT triggers:** (S,G) traffic exceeds configured threshold
2. Configure multiple data MDT thresholds:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt data mpls mldp 50
     mdt data threshold 20
   ```
3. Generate two different multicast streams from R1:
   - Stream 1: 239.1.1.1 (high bandwidth > 20 kbps)
   - Stream 2: 239.1.1.2 (low bandwidth < 20 kbps)
4. Verify: Stream 1 moves to S-PMSI (data MDT), Stream 2 stays on I-PMSI
5. `show ip multicast vrf Customer_A mpls mldp` — identify which streams are on data MDT
6. `show mpls mldp database summary` — count: I-PMSI tree + N data MDT trees
7. **Optimization:** only PEs with receivers for 239.1.1.1 join Stream 1's data MDT

### Task 11: Partitioned MDT (Per-PE I-PMSI)

1. **Default MDT problem:** single shared tree — all PEs send/receive everything on I-PMSI
2. **Partitioned MDT:** each PE builds its OWN P2MP tree for traffic it sources
   - R2's tree: R2 (root) → only PEs with receivers for R2's sources
   - R8's tree: R8 (root) → only PEs with receivers for R8's sources
3. Configure partitioned MDT:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default mpls mldp p2mp
     mdt partitioned mldp p2mp
   ```
4. Verify: `show mpls mldp database` — separate P2MP tree per PE (not one shared tree)
5. Verify: R17 (no receivers) does NOT join ANY tree → receives zero unwanted multicast
6. **Scalability advantage:**
   - Default MDT (100 PEs): every PE in full mesh = 100 trees, all PEs receive all traffic
   - Partitioned MDT (100 PEs, 5 sources, 10 receivers each): 5 trees × 10 leaves = much less state
7. Verify: add a receiver on R18 → R18 joins only the source PE's tree

### Task 12: Wildcard S-PMSI

1. Configure wildcard S-PMSI (group-based selective tree):
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt data mpls mldp 100
     mdt data threshold 0 list MCAST-CHANNELS
   !
   ip access-list standard MCAST-CHANNELS
    permit 239.1.0.0 0.0.255.255
   ```
2. **Threshold 0:** immediately create S-PMSI for matching groups (don't wait for bandwidth)
3. Verify: any (S,G) matching 239.1.0.0/16 gets its own S-PMSI tree immediately
4. Verify: groups NOT matching the ACL stay on I-PMSI until threshold exceeded
5. **IPTV use case:** all TV channels (239.1.x.x) get dedicated S-PMSIs immediately — viewers only pull channels they watch
6. `show ip bgp ipv4 mvpn vrf Customer_A route-type 3` — S-PMSI AD for each channel

---

## Section 5: BGP Auto-Discovery Details

### Task 13: BGP AD Route Type Deep Dive

1. Examine all BGP mVPN route types present in the network:
   ```
   show ip bgp ipv4 mvpn all
   ```
2. For each route type, decode the NLRI:
   - **Type 1 (Intra-AS I-PMSI AD):**
     ```
     show ip bgp ipv4 mvpn vrf Customer_A route-type 1 detail
     ```
     - RD + Originating Router (PE loopback)
     - PMSI Tunnel Attribute: tunnel-type, label, tunnel-identifier
   - **Type 3 (S-PMSI AD):**
     - RD + Source + Group + Originating Router
     - PMSI Tunnel Attribute identifying the S-PMSI tree
   - **Type 4 (Leaf AD):**
     - Mirrors Type 3 — "I want to join"
     - Contains: RT of the VPN + reference to the Type 3 route
   - **Type 5 (Source Active):**
     - RD + Source + Group
     - Signals: "active source exists for this (S,G)"
3. Verify: Type 1 routes carry RT (route-target) for VPN membership filtering
4. Verify: RT-constraint (from Lab 8) applies to mVPN routes too — PEs without the VRF don't receive them
5. `show ip bgp ipv4 mvpn all community` — verify RT communities on mVPN routes

### Task 14: Inter-AS mVPN with BGP AD (Concept)

1. **Type 2 route:** Inter-AS I-PMSI AD — extends auto-discovery across AS boundaries
2. Concept: PE in AS 64512 advertises Type 2 → ASBR carries to PE in remote AS
3. Required: MP-BGP for mvpn address-family between ASBRs (like Option B for L3VPN)
4. Document the architecture:
   - AS 64512: I-PMSI within AS (Type 1)
   - Inter-AS: stitched at ASBR using Type 2 AD
   - Remote AS: separate I-PMSI (Type 1 in their AS)
5. **Note:** inter-AS mVPN is typically configured on IOS-XR — document for reference
6. Verify: `show ip bgp ipv4 mvpn all route-type 2` — Type 2 routes (if inter-AS is configured)

### Task 15: mVPN Extranet (Multicast Across VRFs)

1. **Scenario:** multicast source in Customer_A, receiver in Customer_B
2. On R2 (PE with source): export multicast routes from Customer_A:
   ```
   vrf definition Customer_A
    address-family ipv4
     route-target export 64512:100
   ```
3. On R8 (PE with receiver): import Customer_A's multicast into Customer_B:
   ```
   vrf definition Customer_B
    address-family ipv4
     route-target import 64512:100
     mdt default mpls mldp 2.2.2.2
   ```
4. Verify: receiver in Customer_B can join multicast group from Customer_A's source
5. Verify: `show ip mroute vrf Customer_B` — (S,G) entry with source from Customer_A
6. **Use case:** shared multicast services (video feeds) delivered to multiple customer VPNs
7. **Security:** RT import/export controls exactly which VPNs can access shared multicast

---

## CCIE+ Challenges

### Challenge 1: Profile 14 — MP2MP with BGP AD

1. **Profile 14:** MP2MP mLDP tree (any PE can be source AND receiver)
2. Configure:
   ```
   vrf definition Customer_A
    address-family ipv4
     mdt default mpls mldp mp2mp 3.3.3.3
   ```
3. Any PE with Customer_A can send multicast → all others receive (bidirectional)
4. Verify: `show mpls mldp database` — MP2MP FEC type (not P2MP)
5. **Use case:** customer with multiple multicast sources across different sites
6. Compare: P2MP (unidirectional from root) vs MP2MP (bidirectional from any leaf)
7. Document: when would you choose MP2MP over P2MP?

### Challenge 2: mVPN with Dual-Homed PE

1. Customer site connected to two PEs (R2 and R8): which PE sources the MDT?
2. Configure Designated Forwarder (DF) election:
   - DF for a given (S,G) is the PE with best path to source
3. Verify: `show ip multicast vrf Customer_A df` — DF election result
4. Shut one PE's CE link → DF shifts to surviving PE
5. Verify: multicast traffic seamlessly switches to new DF
6. **Problem:** traffic duplication during DF election — how to prevent?
7. Document: DF election algorithm and convergence time

### Challenge 3: mVPN Rate Limiting and Policing

1. Configure per-VRF multicast rate limiting:
   ```
   interface GigabitEthernet1/0 (CE-facing)
    rate-limit input access-group 101 10000000 1000000 2000000 conform-action transmit exceed-action drop
   !
   access-list 101 permit ip any 239.0.0.0 0.255.255.255
   ```
2. Rate-limit multicast from CE to 10 Mbps
3. Verify: high-bandwidth multicast beyond 10 Mbps gets policed
4. **SP use case:** customer pays for 10 Mbps multicast service — policing enforces the SLA
5. Configure per-group rate limiting (different rate per multicast group)
6. Verify: group 239.1.1.1 gets 5 Mbps, group 239.1.1.2 gets 2 Mbps

### Challenge 4: mVPN Monitoring and Troubleshooting

1. Build a monitoring checklist:
   - `show ip bgp ipv4 mvpn all summary` — mVPN BGP session health
   - `show ip bgp ipv4 mvpn vrf X route-type N` — per-type route verification
   - `show mpls mldp database summary` — mLDP tree count and health
   - `show ip multicast vrf X mpls mldp` — VRF multicast state
   - `show ip mroute vrf X count` — multicast forwarding counters
2. Simulate failure: shut a PE's core link — trace the recovery:
   - Type 1 AD withdrawn → peers detect PE loss
   - Receivers re-signal via alternate PE (if dual-homed)
   - S-PMSI trees rebuild
3. Measure: multicast traffic recovery time during PE failure
4. Verify: `debug ip bgp ipv4 mvpn updates` — watch BGP AD route changes in real time
5. Document: common mVPN failure modes and diagnostic approach

---

## Final Validation

By the end of this lab, your network has:

- [ ] I-PMSI and S-PMSI concepts understood and verified
- [ ] BGP Auto-Discovery (mvpn address-family) configured on all PEs and RRs
- [ ] BGP AD Type 1 routes advertising PE participation in VPN
- [ ] BGP AD Type 3/4 routes signaling S-PMSI creation and leaf joins
- [ ] BGP AD Type 5 routes announcing active multicast sources
- [ ] Profile 6 concept configured (mLDP transport + BGP C-multicast signaling)
- [ ] BGP C-multicast signaling replacing in-band PIM between PEs
- [ ] S-PMSI automatically created when stream exceeds threshold
- [ ] Profile 7 architecture documented (RSVP-TE P2MP with BGP signaling)
- [ ] Bandwidth reservation per multicast tree (P2MP TE concept)
- [ ] Data MDT with threshold-based S-PMSI creation
- [ ] Partitioned MDT reducing unnecessary traffic to non-receiver PEs
- [ ] Wildcard S-PMSI for immediate per-group selective trees
- [ ] BGP AD route types decoded and understood (Types 1-5)
- [ ] (CCIE+) Profile 14 MP2MP tree for bidirectional multicast
- [ ] (CCIE+) Dual-homed PE with DF election for multicast
- [ ] (CCIE+) mVPN monitoring and troubleshooting methodology documented
