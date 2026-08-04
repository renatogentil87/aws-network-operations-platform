# Troubleshooting Lab 4: L3VPN Advanced (Inter-AS, CSC) — 20 Tickets

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 24 routers — 2 SP domains (AS 64512, AS 64513), 8 PEs, 6 P routers, 4 ASBRs, 6 CEs
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change AS numbers or inter-AS connectivity type unless explicitly required
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
| PE (SP-A) | R1, R4 | 64512 |
| PE (SP-B) | R11, R14 | 64513 |
| P (SP-A) | R2, R3 | 64512 |
| P (SP-B) | R12, R13 | 64513 |
| ASBR (SP-A) | R5, R6 | 64512 |
| ASBR (SP-B) | R15, R16 | 64513 |
| RR (SP-A) | R3 | 64512 |
| RR (SP-B) | R13 | 64513 |
| CE | R20 (65001), R21 (65002), R22 (65003), R23 (65004), R24 (65005), R25 (65006) |

**Inter-AS Models:**
- Option-A (back-to-back VRF): R5↔R15
- Option-B (ASBR vpnv4 exchange): R6↔R16

**VPNs:**
- Customer_X: R20 (SP-A) ↔ R22 (SP-B) via Option-A
- Customer_Y: R21 (SP-A) ↔ R23 (SP-B) via Option-B
- Customer_Z: R24 (SP-A) ↔ R25 (SP-B) via Option-B (CSC customer — carrier's carrier)

---

## Ticket 1

The Option-A inter-AS link between R5 and R15 has a VRF interface configured on both sides, but the PE-CE protocol (eBGP) across the inter-AS link is not establishing. IP connectivity across the link (ping) works.

Fix the network so that the eBGP session across the Option-A inter-AS link establishes.

Verify: `show ip bgp vrf Customer_X summary` on R5 shows the session with R15 as Established.

Score: 2 Points

---

## Ticket 2

Customer_X CE (R20) behind SP-A can reach the ASBR (R5) VRF interface but cannot reach Customer_X CE (R22) behind SP-B. The Option-A eBGP session between ASBRs is Established. Routes are being exchanged.

Fix the network so that R20 can reach R22's loopback.

Verify: `ping 22.22.22.22 source 20.20.20.20` from R20 succeeds.

Score: 2 Points

---

## Ticket 3

The Option-B inter-AS link between R6 and R16 has an eBGP multihop session configured for vpnv4 exchange. The session is stuck in Active state. Both ASBRs can ping each other's directly connected interface.

Fix the network so that the vpnv4 eBGP session between R6 and R16 establishes.

Verify: `show ip bgp vpnv4 all summary` on R6 shows the session with R16 as Established with non-zero PfxRcvd.

Score: 2 Points

---

## Ticket 4

Option-B is partially working: R6 receives vpnv4 routes from R16, but the next-hop is unreachable. MPLS labels are being exchanged but the transport label (to reach the remote PE) is missing. The SP-A core has no route to SP-B PE loopbacks.

Fix the network so that next-hops for Option-B vpnv4 routes are resolvable.

Verify: `show ip bgp vpnv4 all nexthop` on R6 shows all next-hops as reachable. VPN traffic from SP-A customers to SP-B customers via Option-B works.

Score: 3 Points

---

## Ticket 5

Customer_Y VPN (Option-B) has routes visible on both PEs but data plane traffic fails. Label-switched path from R4 (SP-A PE) reaches R6 (ASBR) correctly, but the next label in the stack is not being swapped at the ASBR for the inter-AS segment.

Fix the network so that the MPLS label stack is correctly maintained across the Option-B boundary.

Verify: `ping 23.23.23.23 source 21.21.21.21` from R21 succeeds. `show mpls forwarding-table` on R6 shows correct label swap for VPN prefixes.

Score: 3 Points

---

## Ticket 6

Route Target (RT) filtering on the Option-A ASBR is dropping Customer_X routes during the VRF-to-VRF handoff. The routes enter the VRF on R5 but are not being redistributed into the inter-AS eBGP session.

Fix the network so that Customer_X routes are properly exchanged across the Option-A boundary.

Verify: `show ip bgp vrf Customer_X` on R15 shows routes from SP-A. `show ip route vrf Customer_X` on R15 shows the routes as installed.

Score: 3 Points

---

## Ticket 7

The CSC (Carrier Supporting Carrier) customer (Customer_Z) requires MPLS labels to be distributed between the CSC-CE and the PE. The eBGP session between R24 (CSC-CE) and R4 (PE) is Established for ipv4+labels, but labels are not being allocated for the CSC-CE's routes.

Fix the network so that MPLS labels are distributed over the PE-CE BGP session for Customer_Z.

Verify: `show ip bgp vrf Customer_Z labels` on R4 shows labels allocated for routes received from R24. `show mpls forwarding-table vrf Customer_Z` shows label entries.

Score: 2 Points

---

## Ticket 8

Option-B next-hop-self on the ASBR is not being applied correctly. R6 is supposed to rewrite the next-hop for vpnv4 routes it receives from R16 to its own loopback before reflecting to the internal RR. The routes reach the RR with the original SP-B next-hop (unreachable from SP-A internals).

Fix the network so that the ASBR rewrites the next-hop for inbound inter-AS vpnv4 routes.

Verify: `show ip bgp vpnv4 all <prefix>` on R3 (RR) shows next-hop as R6's loopback (6.6.6.6), not the SP-B PE loopback.

Score: 3 Points

---

## Ticket 9

An SOO (Site-of-Origin) conflict exists in Customer_X across the Option-A boundary. Both SPs independently assigned the same SOO community to their respective CE connections. Routes from one CE are being rejected by the other SP's PE due to SOO matching.

Fix the network so that SOO-based loop prevention works correctly without blocking legitimate routes.

Verify: `show ip bgp vrf Customer_X` on both PEs shows routes from the remote CE accepted and installed.

Score: 2 Points

---

## Ticket 10

Option-B ASBR R6 has received vpnv4 routes from R16 with a VPN label, but the label is not being retained in R6's adj-RIB-in. The routes show up with an implicit-null label, breaking the label stack for VPN forwarding.

Fix the network so that VPN labels from the remote ASBR are preserved and used for forwarding.

Verify: `show ip bgp vpnv4 all labels` on R6 shows valid non-null labels for routes received from R16.

Score: 2 Points

---

## Ticket 11

Customer_Y has dual-homed into SP-A via both R1 and R4. Routes from R21 (behind R4) are preferred over routes from a second CE (behind R1) even though the path via R1 should be preferred (shorter AS_PATH from the customer side). The RR is selecting the wrong best path.

Fix the network so that the RR selects the path via R1 as best for the dual-homed prefix.

Verify: `show ip bgp vpnv4 vrf Customer_Y <prefix>` on the RR shows the path via R1 as `>` (best).

Score: 3 Points

---

## Ticket 12

The Option-A ASBR (R5) has a route-map applied to the inter-AS eBGP session that is matching on an incorrect community value. It should permit Customer_X routes but is also inadvertently permitting routes from other VRFs, causing route leaking between customers across the inter-AS boundary.

Fix the network so that only Customer_X routes cross the Option-A boundary while other VRF routes are blocked.

Verify: `show ip bgp vrf Customer_X` on R15 shows ONLY Customer_X routes. No routes from other VRFs appear in any VRF on R15.

Score: 3 Points

---

## Ticket 13

CSC customer (Customer_Z) is attempting to run their own MPLS network over the SP's VPN. The PE-CE BGP session has `send-label` configured, but the CSC-CE's internal IGP routes are not receiving labels from the PE. Only the CSC-CE's loopback gets a label, not the transit links.

Fix the network so that ALL CSC-CE routes (including transit prefixes) receive MPLS labels from the PE.

Verify: `show ip bgp vrf Customer_Z labels` on R4 shows labels for all routes received from R24, including /30 transit links.

Score: 4 Points

---

## Ticket 14

Option-B with inter-AS TE: An MPLS TE tunnel from R4 (SP-A PE) destined to R6 (ASBR) is UP, but the VPN traffic is not being steered into the TE tunnel for inter-AS paths. The tunnel has `autoroute announce` configured.

Fix the network so that VPN traffic destined to Option-B remote PEs uses the TE tunnel to reach the ASBR.

Verify: `show ip cef vrf Customer_Y <remote-prefix>` on R4 shows the TE tunnel as the outgoing interface for the first label-push.

Score: 4 Points

---

## Ticket 15

Option-B vpnv4 routes received by R6 from R16 are being advertised to the internal RR with the incorrect RD (Route Distinguisher). The RR receives them but cannot correlate them with the correct VPN. Routes appear in vpnv4 all but are NOT imported into any VRF on local PEs.

Fix the network so that vpnv4 routes maintain correct RD through the Option-B exchange and are importable by local PEs.

Verify: `show ip bgp vpnv4 all <prefix>` on R1 shows the route with a matchable RT. `show ip route vrf Customer_Y` on R1 shows the imported route.

Score: 4 Points

---

## Ticket 16

Inter-AS Option-B with PE-to-PE labeled path (Option-C style): R6 and R16 are exchanging loopback labels via eBGP (labeled unicast). However, the labeled path is broken because one ASBR is allocating per-prefix labels but the other expects per-CE labels or vice versa.

Fix the network so that the end-to-end labeled path between PEs across the inter-AS boundary works correctly.

Verify: `traceroute mpls ipv4 14.14.14.14/32` from R4 shows a complete LSP through the inter-AS boundary. VPN traffic works.

Score: 4 Points

---

## Ticket 17

BGP Confederations: SP-A has been reconfigured to use a BGP confederation (sub-AS 64512.1 and 64512.2) internally. After the change, VPN routes are no longer reaching PEs in the OTHER sub-AS. The confederation eBGP sessions between sub-AS members are Established.

Fix the network so that vpnv4 routes traverse the confederation sub-AS boundary.

Verify: `show ip bgp vpnv4 all` on PEs in both sub-AS segments shows routes from the other segment.

Score: 4 Points

---

## Ticket 18

Complete Option-B failure: Customer_Y VPN has no connectivity. Troubleshooting reveals:
- The vpnv4 eBGP session between R6 and R16 is Established with prefixes exchanged
- Next-hop rewriting is correct
- Labels are preserved
- But the data plane (traceroute MPLS) shows the LSP breaking at the ASBR

The control plane looks correct but the forwarding plane is broken.

Fix ALL issues so that Customer_Y has end-to-end VPN connectivity via Option-B.

Verify: `ping 23.23.23.23 source 21.21.21.21` from R21 succeeds. `traceroute mpls` shows complete LSP.

Score: 5 Points

---

## Ticket 19

Asymmetric routing across inter-AS boundaries: Customer_X traffic flows SP-A→SP-B via Option-A normally, but return traffic (SP-B→SP-A) is attempting to use Option-B (which doesn't have Customer_X configured). Traffic fails in one direction only.

Fix the network so that Customer_X traffic uses Option-A in BOTH directions consistently.

Verify: `ping 22.22.22.22 source 20.20.20.20` from R20 succeeds AND `ping 20.20.20.20 source 22.22.22.22` from R22 succeeds. Traceroute confirms symmetric Option-A path.

Score: 5 Points

---

## Ticket 20

Multi-failure scenario across both inter-AS models:
- Customer_X (Option-A): routes exchanged but data plane black-holes due to label issue
- Customer_Y (Option-B): control plane broken — no routes reaching remote PEs
- Customer_Z (CSC): label allocation works but CSC customer's internal LSP across the SP backbone is broken

Fix ALL three customers simultaneously.

Verify: All three customer VPNs have end-to-end connectivity. R20↔R22, R21↔R23, R24↔R25 all pass ping tests.

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
