# Troubleshooting Lab 3: MP-BGP & Route Reflectors — 20 Tickets

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 18 routers — 6 PEs (R1, R4, R7, R10, R13, R16), 4 P/RR routers, 8 CEs
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change routing protocol boundaries or remove BGP AS numbers
- Do NOT add new interfaces or IP addresses unless explicitly required
- Do NOT remove existing features to resolve a ticket — fix the root cause
- Static routes are NOT permitted unless preconfigured
- Points are awarded for finding AND resolving the fault
- The resolution of one ticket MAY depend on previous tickets
- There are NO physical faults (all interfaces are cabled correctly)
- Use password `cisco` for any authentication if needed

---

## Topology Reference

| Role | Routers | ASN |
|---|---|---|
| PE | R1, R4, R7, R10, R13, R16 | 64512 |
| P/RR | R2, R3 (RR Cluster-A), R5, R6 (RR Cluster-B) | 64512 |
| CE | R20-R27 (various customer ASNs: 65001-65008) |

**RR Clusters:**
- Cluster-A (R2, R3): Serves R1, R4, R7
- Cluster-B (R5, R6): Serves R10, R13, R16

**Address Families:** vpnv4 unicast, vpnv6 unicast, ipv4 unicast
**IGP:** OSPF Area 0 (all P/PE)
**PE-CE:** Mix of eBGP, OSPF, static

---

## Ticket 1

A PE router has no iBGP session to either of its assigned Route Reflectors. The PE can ping both RR loopbacks successfully. Other PEs in the same cluster have working sessions.

Fix the network so that the PE establishes iBGP sessions to both RRs.

Verify: `show ip bgp vpnv4 all summary` on the affected PE shows both RR sessions in Established state.

Score: 2 Points

---

## Ticket 2

An iBGP session between a PE and its RR is Established, but the PE is receiving 0 vpnv4 prefixes. Other PEs connected to the same RR are receiving prefixes normally. The RR has routes in its vpnv4 table.

Fix the network so that the PE receives vpnv4 routes from the RR.

Verify: `show ip bgp vpnv4 all summary` shows non-zero PfxRcvd from the RR.

Score: 2 Points

---

## Ticket 3

Two Route Reflectors in the same cluster are not peering with each other. Each RR has sessions to its PE clients but inter-cluster RR peering is missing, causing incomplete route distribution.

Fix the network so that the intra-cluster RR-to-RR session establishes.

Verify: `show ip bgp vpnv4 all summary` on both RRs shows the peer session Established with non-zero PfxRcvd.

Score: 2 Points

---

## Ticket 4

Routes from Cluster-A PEs are NOT reaching Cluster-B PEs. Cluster-A PEs can reach each other. Cluster-B PEs can reach each other. The inter-cluster RR peering (between Cluster-A and Cluster-B) is Established with non-zero prefixes.

Fix the network so that routes from Cluster-A PEs are visible on Cluster-B PEs.

Verify: `show ip bgp vpnv4 all` on R10 (Cluster-B PE) shows routes originated by R1 (Cluster-A PE).

Score: 3 Points

---

## Ticket 5

A PE is originating vpnv4 routes into BGP (visible locally in `show ip bgp vpnv4 vrf`) but the RR is NOT receiving them. The iBGP session is Established and other address families (if any) are working.

Fix the network so that the PE's vpnv4 routes reach the RR.

Verify: `show ip bgp vpnv4 all` on the RR shows routes with the PE as the originator (next-hop = PE loopback).

Score: 3 Points

---

## Ticket 6

BGP next-hop resolution is failing on a PE. The PE receives vpnv4 routes from the RR but they are marked as "inaccessible" or have invalid next-hop. The IGP routing table is complete (all loopbacks reachable via OSPF).

Fix the network so that all vpnv4 routes have valid, resolvable next-hops.

Verify: `show ip bgp vpnv4 all` — all routes show `>` (valid) and `*` (best) markers. `show ip bgp vpnv4 all nexthop` shows all next-hops as reachable.

Score: 3 Points

---

## Ticket 7

A Route Reflector is reflecting routes back to the originating PE (route loop). The PE sees its own originated routes coming back from the RR with modified attributes. This is causing a BGP processing loop.

Fix the network so that the RR does not reflect routes back to their originator.

Verify: `show ip bgp vpnv4 all` on the PE does NOT show its own routes received from the RR. RR reflects only to non-originating clients.

Score: 2 Points

---

## Ticket 8

BGP CLUSTER_LIST loop detection is incorrectly dropping valid routes. Routes originated in Cluster-A are being dropped by Cluster-B RRs due to CLUSTER_LIST containing a cluster-id that matches. The clusters are DIFFERENT and should NOT trigger loop detection.

Fix the network so that inter-cluster routes are accepted and reflected.

Verify: `show ip bgp vpnv4 all <prefix>` on Cluster-B RRs shows the route accepted from Cluster-A with correct CLUSTER_LIST.

Score: 3 Points

---

## Ticket 9

A PE configured with `next-hop-self` for its RR sessions is breaking VPN label forwarding. The PE is rewriting next-hop for vpnv4 routes it reflects, but since it's a client (not an RR), it shouldn't be modifying routes from the RR.

Fix the network so that vpnv4 routes maintain their original next-hop through the RR infrastructure.

Verify: `show ip bgp vpnv4 all <prefix>` on destination PEs shows the originating PE's loopback as next-hop (not the intermediate PE's loopback).

Score: 2 Points

---

## Ticket 10

BGP bestpath selection is choosing a suboptimal route on the RR. A route with a longer AS_PATH is being selected as best over a route with a shorter AS_PATH. Both routes have the same LOCAL_PREF and WEIGHT.

Fix the network so that BGP bestpath selection follows the standard decision process (shorter AS_PATH preferred).

Verify: `show ip bgp vpnv4 all <prefix>` on the RR shows the shorter AS_PATH route as `>` (best).

Score: 2 Points

---

## Ticket 11

RT (Route Target) filtering on the RR is causing legitimate VPN routes to be dropped before reflection. The RR has RT-constrained route distribution configured, but one PE's RT is missing from the filter, causing its VPN to be invisible to remote PEs.

Fix the network so that all configured VPN RTs are accepted by the RR for reflection.

Verify: `show ip bgp vpnv4 all` on the RR shows routes with all configured RTs. Remote PEs import the routes into their VRFs.

Score: 3 Points

---

## Ticket 12

A PE-CE eBGP session is Established but the CE is not receiving any VPN routes from the PE. The PE's VRF has routes in its BGP table. The PE-CE session shows non-zero routes advertised from the PE's perspective.

Fix the network so that the CE receives VPN routes from the PE.

Verify: `show ip bgp` on the CE shows routes received from the PE. `show ip route bgp` on the CE shows installed BGP routes.

Score: 3 Points

---

## Ticket 13

SOO (Site-of-Origin) is configured to prevent routing loops in a dual-homed customer scenario. However, the SOO is incorrectly blocking legitimate routes. The customer has two CE routers connecting to two different PEs — one site's routes are completely missing from the other site.

Fix the network so that both sites can reach each other while maintaining loop prevention.

Verify: Both CEs have routes to each other. `show ip bgp vpnv4 vrf` on both PEs shows routes from both CEs with correct SOO attributes.

Score: 4 Points

---

## Ticket 14

BGP Graceful Restart is misconfigured between a PE and its RR. After a PE reload simulation (clear ip bgp), the RR immediately withdraws ALL routes from that PE instead of maintaining them during the restart period. This causes a traffic black hole during maintenance.

Fix the network so that BGP Graceful Restart preserves routes during a PE session reset.

Verify: `clear ip bgp <RR-IP> soft` on PE — during the restart, other PEs still have routes with that PE as next-hop. Routes are marked as stale but remain usable.

Score: 4 Points

---

## Ticket 15

BGP Additional Paths (ADD-PATH) has been configured on the RRs to advertise multiple paths for the same prefix. However, client PEs are only receiving ONE path per prefix despite multiple paths existing on the RR.

Fix the network so that PEs receive multiple paths for prefixes that have them.

Verify: `show ip bgp vpnv4 all <prefix>` on a PE shows multiple paths received from the RR (not just the best path).

Score: 4 Points

---

## Ticket 16

A PE-CE eBGP session using AS-override is causing a routing loop. The customer has sites in ASN 65001 behind two different PEs. AS-override replaces the customer ASN, defeating the AS_PATH loop detection. Routes are bouncing between sites.

Fix the network so that the dual-homed customer has loop-free routing while maintaining AS-override functionality.

Verify: `show ip bgp vrf <vrf>` on both PEs shows routes from both CEs without routing loops. Traceroute between CEs shows a direct path.

Score: 4 Points

---

## Ticket 17

BGP route dampening on the RR is suppressing VPN routes that had a single flap event 2 hours ago. The route is stable now but remains suppressed because the penalty has not decayed below the reuse limit. Customer traffic to that prefix is black-holed.

Fix the network so that the suppressed route is restored and future dampening parameters are reasonable.

Verify: `show ip bgp vpnv4 all dampened-paths` — the affected route is no longer suppressed. `show ip bgp vpnv4 all <prefix>` shows the route as best/valid.

Score: 4 Points

---

## Ticket 18

Full RR failure scenario: BOTH Route Reflectors in Cluster-A have simultaneously lost their client sessions to ALL PEs. The RR-to-RR peering between clusters is still UP. PE-to-PE reachability (IGP/LDP) is fine. The issue is BGP-specific and affects only Cluster-A.

Fix the network so that all Cluster-A PEs re-establish sessions and receive full vpnv4 routing.

Verify: `show ip bgp vpnv4 all summary` on R1, R4, R7 shows Established sessions with non-zero PfxRcvd from at least one RR.

Score: 5 Points

---

## Ticket 19

BGP route oscillation: a vpnv4 prefix is flapping between two paths every 30-60 seconds on the RR. Both paths are valid but the RR keeps changing its best path selection. No actual topology changes are occurring. The oscillation is propagated to all client PEs.

Fix the network so that the RR selects a stable best path that does not oscillate.

Verify: `show ip bgp vpnv4 all <prefix>` — the best path remains consistent over 5 minutes. No BGP update messages for this prefix in `debug ip bgp updates`.

Score: 5 Points

---

## Ticket 20

Multiple simultaneous BGP issues:
- Cluster-A PEs receive vpnv4 routes but with incorrect next-hop (unreachable next-hop)
- Cluster-B PEs receive routes with correct next-hop but wrong RD, causing VRF import failure
- Inter-cluster route exchange appears to work (prefixes seen on both sides) but NO VPN has end-to-end data plane connectivity

Fix all issues so that full VPN connectivity is restored across both clusters.

Verify: Customer CEs behind Cluster-A PEs can ping CEs behind Cluster-B PEs. `show ip bgp vpnv4 all` shows valid, resolvable next-hops on all PEs. VRF routing tables show imported routes.

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
