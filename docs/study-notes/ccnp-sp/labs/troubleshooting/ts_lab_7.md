# Troubleshooting Lab 7: Segment Routing (SR-MPLS) — 20 Tickets

**Platform:** GNS3 Local (Cisco XRv 9000, IOS-XR 7.x)
**Topology:** 14 routers — 4 PEs (R1, R5, R9, R14), 8 P routers, 2 CEs
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change IS-IS areas or segment routing global block (SRGB) ranges
- Do NOT add new interfaces or IP addresses unless explicitly required
- Do NOT remove existing features to resolve a ticket — fix the root cause
- Static routes are NOT permitted unless preconfigured
- Points are awarded for finding AND resolving the fault
- The resolution of one ticket MAY depend on previous tickets
- There are NO physical faults (all interfaces are cabled correctly)
- Use password `cisco` for any authentication if needed

---

## Topology Reference

| Role | Routers | Prefix-SID |
|---|---|---|
| PE | R1 (SID 101), R5 (SID 105), R9 (SID 109), R14 (SID 114) | 16000+index |
| P (north) | R2 (SID 102), R3 (SID 103), R4 (SID 104) | 16000+index |
| P (south) | R6 (SID 106), R7 (SID 107), R8 (SID 108) | 16000+index |
| P (cross) | R10 (SID 110), R11 (SID 111) | 16000+index |
| CE | R20 (AS 65001), R21 (AS 65002) |

**SRGB:** 16000-23999 (all routers)
**IGP:** IS-IS single-area (49.0001) with SR extensions
**SR Policy:** On-Demand Next-hop (ODN) for VPN traffic
**TI-LFA:** Enabled on all core links
**Flex-Algo:** Algo 128 (low-latency) on south path (R6-R7-R8)

---

## Ticket 1

R1's prefix-SID (16101) is not being advertised in IS-IS. Other routers cannot reach R1 via the SR label path (LFIB shows no entry for label 16101). R1's IS-IS adjacencies are healthy.

Fix the network so that R1 advertises its prefix-SID into IS-IS.

Verify: `show isis database detail` on R3 shows R1's prefix-SID in the SR sub-TLV. `show mpls forwarding` on R3 shows label 16101 with a valid outgoing path.

Score: 2 Points

---

## Ticket 2

R5 has a prefix-SID conflict with another router — both are advertising SID index 105. The IS-IS database shows the conflict and SR is not installing labels for either prefix. One router needs its SID index changed.

Fix the network so that all prefix-SIDs are unique and labels are installed for both prefixes.

Verify: `show isis segment-routing prefix-sid-map` shows no conflicts. `show mpls forwarding` shows valid entries for both previously conflicting prefixes.

Score: 2 Points

---

## Ticket 3

The SRGB on one P router is misconfigured (different range than all others). Its locally allocated labels don't align with the global prefix-SID values. LSPs traversing this router break because label values are inconsistent.

Fix the network so that the SRGB is consistent across all routers.

Verify: `show isis segment-routing` on all routers shows the same SRGB range. `traceroute mpls segment-routing` from R1 to R5 shows complete LSP.

Score: 2 Points

---

## Ticket 4

SR-MPLS forwarding is working between PEs for infrastructure (ping between loopbacks succeeds), but VPN traffic (L3VPN) is NOT using SR transport. VPN routes exist in the BGP table with valid next-hops, but the label stack shows LDP labels instead of SR prefix-SIDs.

Fix the network so that VPN traffic uses SR-MPLS transport labels (prefix-SIDs) instead of LDP.

Verify: `show cef vrf Customer_A <remote-prefix>` shows the transport label is a prefix-SID (16xxx range). VPN traffic works.

Score: 3 Points

---

## Ticket 5

TI-LFA (Topology Independent Loop-Free Alternate) is configured but NOT providing backup paths on R3. When the R3-R4 link fails, traffic to R4/R5/R9 is black-holed for 1-2 seconds (full IGP convergence time) instead of using a pre-computed backup.

Fix the network so that TI-LFA provides sub-50ms protection on R3 for the R3-R4 link.

Verify: `show isis fast-reroute` on R3 shows TI-LFA backup path computed for R4's prefix. Link failure test shows <50ms traffic loss.

Score: 3 Points

---

## Ticket 6

TI-LFA backup path on R2 requires a repair label (additional SID in the label stack to steer traffic around the failure). However, the backup label stack shows only the prefix-SID of the destination without the repair SID. Traffic during failure takes a loop.

Fix the network so that TI-LFA computes the correct repair label stack (P-node or Q-node SID).

Verify: `show isis fast-reroute detail` on R2 shows the backup path with the repair segment(s). Failure test shows loop-free recovery.

Score: 3 Points

---

## Ticket 7

SR Policy (explicit path via segment-list) from R1 to R9 through the north path (R2→R3→R4→R9) is not installing in the forwarding table. The policy is configured with a segment-list containing adjacency-SIDs, but one adjacency-SID value is incorrect.

Fix the network so that the SR Policy installs with the correct segment-list.

Verify: `show segment-routing traffic-eng policy` on R1 shows the policy as active with a valid forwarding entry. `traceroute segment-routing` confirms the explicit north path.

Score: 2 Points

---

## Ticket 8

Flex-Algo 128 (low-latency) is configured on the south-path routers (R6, R7, R8) and PEs. R1 should be able to steer traffic to R9 via the low-latency path by using a Flex-Algo prefix-SID. However, R1's LFIB shows no entry for R9's Flex-Algo SID (16209).

Fix the network so that Flex-Algo 128 SIDs are computed and installed on all participating routers.

Verify: `show isis flex-algo 128` shows participating routers and their prefix-SIDs. `show mpls forwarding labels 16209` on R1 shows a valid path via the south nodes.

Score: 3 Points

---

## Ticket 9

Microloop avoidance using SR: After a link failure, a transient microloop forms for 1-2 seconds before all routers converge. SR microloop avoidance (local delay) is configured but not activating — traffic still loops briefly during convergence.

Fix the network so that SR microloop avoidance prevents transient loops during convergence.

Verify: Link failure test — no packet loss from loops (may see brief sub-second loss from the convergence itself but no looping). `show isis microloop-avoidance` confirms the feature is active.

Score: 2 Points

---

## Ticket 10

On-Demand Next-hop (ODN) for L3VPN: BGP vpnv4 routes with a color community (color 100) should trigger automatic SR Policy creation to reach the BGP next-hop via a constrained path. The ODN policy is not being created — VPN traffic uses the default IGP path.

Fix the network so that ODN creates SR Policies for colored BGP next-hops.

Verify: `show segment-routing traffic-eng policy color 100` shows auto-created policies. VPN traffic uses the SR Policy path instead of shortest IGP path.

Score: 2 Points

---

## Ticket 11

Anycast-SID: R3 and R7 are configured with the same anycast prefix-SID (16200) for load-balancing. However, traffic from R1 always goes to R3 (never R7). The anycast SID should distribute traffic to the nearest instance.

Fix the network so that the anycast-SID correctly resolves to the topologically closest node from each source.

Verify: From R1, `show mpls forwarding labels 16200` points toward R3 (closer). From R14, it points toward R7 (closer). Both resolve correctly based on IGP distance.

Score: 3 Points

---

## Ticket 12

SR-MPLS ping/traceroute (OAM) is failing. `traceroute mpls segment-routing` from R1 to R5 shows "!N" (no FEC) at intermediate hops. The data plane works (VPN traffic flows), but the OAM mechanism cannot validate the LSP.

Fix the network so that SR-MPLS OAM (ping/traceroute) works end-to-end.

Verify: `traceroute mpls segment-routing ipv4 5.5.5.5/32` from R1 shows successful responses from each hop along the path.

Score: 3 Points

---

## Ticket 13

Binding-SID: An SR Policy has been created with binding-SID 15001 to represent an end-to-end path. Remote routers should be able to steer traffic into this policy by pushing label 15001. However, the binding-SID is not being programmed in the LFIB.

Fix the network so that the binding-SID is installed and remote routers can use it to steer traffic into the SR Policy.

Verify: `show mpls forwarding labels 15001` on R1 shows the binding-SID mapped to the SR Policy path. Traffic pushed with label 15001 follows the policy.

Score: 4 Points

---

## Ticket 14

SR Policy with weighted ECMP (multiple segment-lists, different weights): A policy has two candidate paths — 70% via north, 30% via south. However, all traffic is going 50/50 or 100% on one path. The weighted load-balancing is not being respected.

Fix the network so that traffic distribution matches the configured weights (70/30 split).

Verify: `show segment-routing traffic-eng policy detail` shows both segment-lists active with correct weights. Traffic counters confirm approximate 70/30 distribution.

Score: 4 Points

---

## Ticket 15

TI-LFA with SR Policy interaction: An SR Policy forces traffic via a specific path, but when TI-LFA activates (link failure on the policy path), the backup path conflicts with the SR Policy intent. Traffic is rerouted to a path that violates the policy constraint (e.g., goes through a node it should avoid).

Fix the network so that TI-LFA backup paths respect SR Policy constraints.

Verify: During a link failure, traffic stays within the SR Policy's allowed topology. `show segment-routing traffic-eng policy detail` shows the policy with updated backup path that maintains constraints.

Score: 4 Points

---

## Ticket 16

Prefix-SID vs Adjacency-SID interaction: A segment-list uses both prefix-SIDs and adjacency-SIDs. The adjacency-SID at one hop is a dynamic value that changed after a router reload. The segment-list has the stale adjacency-SID value, causing the LSP to break at that hop.

Fix the network so that the SR Policy uses stable (persistent/static) adjacency-SIDs that survive reloads.

Verify: `show isis adjacency-log` — adjacency-SID remains constant across reload. The SR Policy path is valid after router reload.

Score: 4 Points

---

## Ticket 17

Flex-Algo constraint propagation: Flex-Algo 128 should avoid R10 and R11 (exclude affinity "maintenance"). The algo definition is correct on the Flex-Algo definition router, but R6 is NOT receiving the constraint — it still includes R10 in its Flex-Algo SPF computation.

Fix the network so that ALL Flex-Algo 128 participants receive and honor the exclude constraint.

Verify: `show isis flex-algo 128` on all participating routers shows the same constraints. The computed Flex-Algo tree excludes R10 and R11.

Score: 4 Points

---

## Ticket 18

Complete SR forwarding failure: All SR label entries have disappeared from the LFIB on R3. IS-IS adjacencies are UP, prefix-SIDs are advertised by peers, but R3 shows an empty `show mpls forwarding` table. LDP is not configured (SR-only network). All traffic through R3 is being dropped.

Fix the network so that R3's LFIB is populated with SR label entries and forwarding is restored.

Verify: `show mpls forwarding` on R3 shows entries for all prefix-SIDs. Traffic transiting R3 is forwarded correctly. `traceroute mpls` through R3 succeeds.

Score: 5 Points

---

## Ticket 19

SR Policy path computation loop: An SR Policy from R1 to R9 with a dynamic path (computed by headend) is constantly being recomputed every 5 seconds. Each computation produces a DIFFERENT path. No topology changes are occurring. The headend is oscillating between two equal-cost paths but never settling.

Fix the network so that the SR Policy computation is stable and the path remains constant.

Verify: `show segment-routing traffic-eng policy` — path remains unchanged for 5+ minutes. No recomputation events in the log.

Score: 5 Points

---

## Ticket 20

Multi-failure scenario:
- R1→R5: SR transport broken (prefix-SID not installed on intermediate router)
- R1→R9: SR Policy active but using wrong path (affinity constraint violated)
- R14→R5: TI-LFA backup computes but doesn't install in LFIB
- Flex-Algo 128: Only 2 of 5 participating routers have the algo active

Fix ALL SR issues simultaneously so that complete SR-MPLS functionality is restored.

Verify: All PE-to-PE SR paths work. TI-LFA provides protection. Flex-Algo 128 path available on all participants. SR Policies follow constraints.

Score: 5 Points

---

## Scoring Summary

| Tickets | Difficulty | Points Each | Total |
|---|---|---|---|
| 1-3 | CCNP-SP (⭐⭐) | 2 | 6 |
| 4-6 | CCNP-SP (⭐⭐⭐) | 3 | 9 |
| 7-9 | CCNP-SP (⭐⭐⭐) | 2-3 | 7 |
| 10-12 | CCNP→CCIE (⭐⭐⭐) | 2-3 | 8 |
| 13-17 | CCIE-SP (⭐⭐⭐⭐) | 4 | 20 |
| 18-20 | CCIE-SP (⭐⭐⭐⭐⭐) | 5 | 15 |
| **Total** | | | **65 Points** |

**Passing:** 49/65 (75%)
**CCIE-ready:** 59/65 (90%)
