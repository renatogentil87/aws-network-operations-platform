# Troubleshooting Lab 1: IS-IS SP Core — 20 Tickets

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 16 routers — 4 PEs (R1, R6, R11, R16), 8 P routers, 4 CEs
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change routing protocol boundaries or remove IS-IS area assignments
- Do NOT add new interfaces or IP addresses unless explicitly required
- Do NOT remove existing features to resolve a ticket — fix the root cause
- Static routes are NOT permitted unless preconfigured
- Points are awarded for finding AND resolving the fault
- The resolution of one ticket MAY depend on previous tickets
- There are NO physical faults (all interfaces are cabled correctly)
- Use password `cisco` for any authentication if needed

---

## Topology Reference

| Role | Routers | Level |
|---|---|---|
| PE | R1, R6, R11, R16 | L1/L2 |
| P (backbone) | R2, R3, R4, R5 | L2-only |
| P (access) | R7, R8, R9, R10 | L1/L2 |
| CE | R20 (AS 65001), R21 (AS 65002), R22 (AS 65003), R23 (AS 65004) |

**IS-IS Areas:**
- Area 49.0001: R1, R2, R3, R7, R8 (Region West)
- Area 49.0002: R4, R5, R6, R9, R10 (Region East)
- Area 49.0003: R11, R16 (Region South)

**NET Addressing:** `49.000X.YYYY.YYYY.YYYY.00` where X=area, Y=derived from loopback
**IGP:** IS-IS (single topology, wide metrics)
**Label Distribution:** LDP on all core interfaces
**MPLS:** Enabled on all core-facing interfaces

---

## Ticket 1

Two directly connected P routers in the backbone cannot form an IS-IS adjacency. Both routers show the interface as UP/UP. Other IS-IS adjacencies on both routers are healthy.

Fix the network so that the IS-IS adjacency forms between the affected routers.

Verify: `show clns neighbors` on both routers shows the adjacency in UP state. `show isis neighbors` confirms L2 adjacency.

Score: 2 Points

---

## Ticket 2

R1 (PE) has an IS-IS adjacency with its directly connected P router, but R1's loopback is NOT appearing in the IS-IS database of remote routers. Other PE loopbacks are visible network-wide.

Fix the network so that R1's loopback is advertised into IS-IS and reachable from all other routers.

Verify: `show isis database detail` on any remote P router shows R1's loopback prefix. `ping 1.1.1.1` from R6 succeeds.

Score: 2 Points

---

## Ticket 3

IS-IS adjacency between an L1/L2 router and an L2-only backbone router is stuck in INIT state. Both routers see each other's IIH packets (confirmed via debug) but never transition to UP.

Fix the network so that the adjacency reaches UP state.

Verify: `show clns neighbors` shows UP state. `show isis neighbors detail` shows the adjacency as L2.

Score: 2 Points

---

## Ticket 4

R11 (PE, Area 49.0003) cannot reach R1's loopback (1.1.1.1) despite having healthy IS-IS adjacencies. R11's IS-IS routing table shows routes for Area 49.0002 but is missing ALL routes from Area 49.0001.

Fix the network so that R11 has full reachability to all PE and P loopbacks.

Verify: `show isis route` on R11 shows prefixes from all three areas. `ping 1.1.1.1 source 11.11.11.11` succeeds.

Score: 3 Points

---

## Ticket 5

LDP sessions are NOT forming between R1 and R6 even though both routers have full IS-IS reachability to each other's loopbacks. LDP sessions between OTHER PE/P pairs are working correctly.

Fix the network so that the LDP session between R1 and R6 establishes.

Verify: `show mpls ldp neighbor 6.6.6.6` on R1 shows the session as Operational.

Score: 3 Points

---

## Ticket 6

IS-IS metric manipulation has caused a routing loop between R3 and R4. Traceroute from R1 to R6 shows packets bouncing between R3 and R4 with TTL expiry. All adjacencies are UP.

Fix the network so that traffic follows a loop-free path from R1 to R6.

Verify: `traceroute 6.6.6.6 source 1.1.1.1` shows a clean path with no loops. All IS-IS metrics are consistent.

Score: 3 Points

---

## Ticket 7

R16 (PE) is advertising its loopback into IS-IS, and other routers see it in their LSDB. However, the route is NOT being installed in the RIB of remote routers. `show isis rib` shows the prefix but with an invalid next-hop or unreachable next-hop.

Fix the network so that R16's loopback is installed in the RIB of all routers.

Verify: `show ip route 16.16.16.16` on R1 shows an IS-IS route with a valid next-hop. `ping 16.16.16.16` from R1 succeeds.

Score: 2 Points

---

## Ticket 8

IS-IS authentication has been configured between two P routers. The adjacency has dropped and IIH packets are being rejected. One router shows authentication mismatch in debug output.

Fix the network so that IS-IS authentication works and the adjacency reforms.

Verify: `show clns neighbors` shows UP state. `show isis neighbors detail` confirms authentication is active on both sides.

Score: 3 Points

---

## Ticket 9

After a router reload, R7 (P router, L1/L2) is leaking L1 routes into L2 that should NOT be leaked. This is causing suboptimal routing for traffic destined to Area 49.0001 internal prefixes.

Fix the network so that only appropriate routes are leaked between levels.

Verify: `show isis database level-2 detail` on backbone routers does NOT show internal L1-only prefixes from Area 49.0001 that should remain internal.

Score: 2 Points

---

## Ticket 10

The IS-IS SPF computation on R3 is running excessively (multiple times per second) causing high CPU. There are no actual topology changes occurring. Other P routers show normal SPF behavior.

Fix the network so that SPF runs at a normal rate on R3.

Verify: `show isis spf-log` on R3 shows reasonable SPF intervals. CPU utilization drops to normal levels.

Score: 2 Points

---

## Ticket 11

BFD has been configured for IS-IS on a link between two P routers, but BFD is not detecting failures. When the link quality degrades (simulated with interface delay), IS-IS takes the full hello dead interval to detect the neighbor loss.

Fix the network so that BFD detects the failure within the configured BFD timers.

Verify: `show bfd neighbors` shows the BFD session as Up. Simulate a failure — IS-IS reconverges within BFD timer values.

Score: 3 Points

---

## Ticket 12

IS-IS is running in single-topology mode but one router has been misconfigured with multi-topology for IPv4. This is causing an adjacency mismatch with its neighbor and the adjacency will not form on one AFI.

Fix the network so that IS-IS topology mode is consistent across the adjacency.

Verify: `show isis neighbors detail` shows the adjacency supporting both IPv4 and (if configured) IPv6. No TLV mismatches in debug output.

Score: 3 Points

---

## Ticket 13

R6 (PE) is receiving IS-IS routes with a next-hop that requires recursive resolution, but the recursion is failing. R6 can reach the ultimate next-hop directly but the RIB shows the IS-IS route as "unresolved."

Fix the network so that all IS-IS routes resolve correctly in R6's RIB.

Verify: `show ip route` on R6 shows all IS-IS routes as installed (no unresolved entries). `show ip cef` shows valid adjacency for all IS-IS prefixes.

Score: 4 Points

---

## Ticket 14

IS-IS overload bit (OL) is set on a P router, causing all transit traffic to avoid it. The router is healthy and should be carrying transit traffic. The overload bit was NOT manually configured — it appears to be triggered by a condition.

Fix the network so that the overload bit is cleared and the router carries transit traffic.

Verify: `show isis database` — the router's LSP does NOT have the OL bit set. Traffic transits through this router.

Score: 4 Points

---

## Ticket 15

An IS-IS prefix that should be reachable via TWO equal-cost paths is only being reached via ONE path. Both paths exist in the LSDB with identical metrics. The router has `maximum-paths 16` configured.

Fix the network so that both equal-cost paths are installed in the RIB and CEF.

Verify: `show ip route <prefix>` shows two next-hops. `show ip cef <prefix>` shows load-sharing across both paths.

Score: 4 Points

---

## Ticket 16

After an IS-IS area merge attempt, two routers in different areas that are now directly connected cannot form an L2 adjacency. Their area addresses have been updated but something prevents the L2 adjacency from forming.

Fix the network so that the L2 adjacency forms between the previously separated areas.

Verify: `show isis neighbors` shows L2 adjacency in UP state between the two routers.

Score: 4 Points

---

## Ticket 17

IS-IS prefix suppression (advertising only the transit link IP, not the full /30) has been configured on several links. One PE's loopback is being suppressed incorrectly — it should NEVER be suppressed. The loopback is missing from other routers' routing tables.

Fix the network so that the PE loopback is advertised while prefix suppression continues on transit links.

Verify: `show isis database detail` shows the PE loopback in the LSP. Transit /30 prefixes remain suppressed. Remote routers have the loopback in their RIB.

Score: 4 Points

---

## Ticket 18

Multiple IS-IS adjacencies are oscillating (flapping every 20-30 seconds) across the entire backbone. CPU is elevated on all affected routers. The interfaces show no errors or CRC issues. Physical layer is clean.

Fix the network so that all IS-IS adjacencies stabilize and remain UP.

Verify: `show isis neighbors` shows all adjacencies stable (uptime increasing). `show log` shows no further adjacency flaps for 2+ minutes.

Score: 5 Points

---

## Ticket 19

R1 and R6 both have routes to R16's loopback, but the path from R1 traverses 6 hops while the optimal path should be 3 hops. The IS-IS metrics appear correct on individual links, but the end-to-end path cost calculation is wrong. One router is running narrow metrics while others use wide metrics.

Fix the network so that the path cost calculation is consistent and R1 reaches R16 via the optimal 3-hop path.

Verify: `traceroute 16.16.16.16 source 1.1.1.1` shows exactly 3 intermediate hops. IS-IS metric style is consistent across all routers.

Score: 5 Points

---

## Ticket 20

Full network convergence failure: R11 and R16 (Area 49.0003) have lost ALL reachability to Areas 49.0001 and 49.0002. Local adjacencies within Area 49.0003 are fine. The L2 backbone appears fragmented. Multiple issues may be contributing simultaneously.

Fix the network so that full inter-area reachability is restored.

Verify: `ping 1.1.1.1 source 11.11.11.11` succeeds. `ping 6.6.6.6 source 16.16.16.16` succeeds. `show isis route` on R11 shows prefixes from all areas.

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
