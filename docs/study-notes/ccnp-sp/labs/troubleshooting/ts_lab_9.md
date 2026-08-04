# Troubleshooting Lab 9: Multicast in SP Core (mVPN) — 20 Tickets

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 16 routers — 4 PEs (R1, R5, R9, R13), 4 P routers, 4 multicast sources, 4 receivers
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change PIM mode, VRF definitions, or MPLS core configuration unless explicitly required
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
| PE | R1, R5, R9, R13 | 64512 |
| P (core) | R2, R3, R6, R10 | — |
| RR | R3 | 64512 |
| Source CE | R20 (239.1.1.1), R21 (239.2.2.2) |
| Receiver CE | R22, R23, R24, R25 |

**Multicast:**
- Core: PIM-SSM (default MDT with GRE/mLDP)
- VPN: mVPN Profile 0 (Default MDT — GRE) for VPN_Mcast_A
- VPN: mVPN Profile 1 (Default MDT — mLDP) for VPN_Mcast_B
- Default MDT group: 232.1.1.1 (VPN_A), 232.2.2.2 (VPN_B)
- RP: R3 loopback (core PIM-SM), static RP in VRFs

**BGP:** vpnv4 + mdt SAFI for mVPN auto-discovery

---

## Ticket 1

PIM adjacency between two P routers in the core is not forming. Both interfaces have `ip pim sparse-mode` configured. The interface is UP/UP and OSPF adjacency is FULL on the same link.

Fix the network so that the PIM adjacency establishes between the P routers.

Verify: `show ip pim neighbor` on both routers shows the adjacency. `show ip mroute` on downstream routers shows the core MDT group.

Score: 2 Points

---

## Ticket 2

The default MDT for VPN_Mcast_A is not being established. R1 (source PE) has the MDT configured (group 232.1.1.1) but no other PE is joining the MDT tunnel. `show ip mroute 232.1.1.1` on P routers shows no state.

Fix the network so that all PEs join the default MDT for VPN_Mcast_A.

Verify: `show ip mroute 232.1.1.1` on P routers shows (S,G) or (*,G) state with all PE loopbacks as sources. `show ip pim mdt` on PEs shows the MDT tunnel UP.

Score: 2 Points

---

## Ticket 3

BGP mdt SAFI (address family ipv4 mdt) is not configured between PEs and the RR. mVPN auto-discovery routes are not being exchanged. Vpnv4 routes work, but multicast VPN routes have no BGP transport.

Fix the network so that mVPN auto-discovery (MDT SAFI) is enabled between PEs and the RR.

Verify: `show ip bgp ipv4 mdt all` on the RR shows mVPN routes from multiple PEs.

Score: 2 Points

---

## Ticket 4

Multicast source R20 (behind R1, VPN_Mcast_A) is sending to 239.1.1.1 but receiver R22 (behind R5) does NOT receive the stream. The source PE (R1) shows (S,G) state in the VRF mroute table. The receiver PE (R5) shows NO mroute state for that group.

Fix the network so that multicast traffic from R20 reaches R22 across the mVPN.

Verify: `show ip mroute vrf VPN_Mcast_A 239.1.1.1` on R5 shows (S,G) state with active incoming interface. R22 receives the multicast stream.

Score: 3 Points

---

## Ticket 5

The multicast RP within VPN_Mcast_A is misconfigured. PEs have different RP addresses configured for the VRF. Source registration is going to one RP address while receivers join toward a different RP. The SPT switchover never happens.

Fix the network so that all PEs agree on the VRF RP and source-to-receiver multicast path is established.

Verify: `show ip pim vrf VPN_Mcast_A rp mapping` on all PEs shows the same RP address. `show ip mroute vrf VPN_Mcast_A` shows active (S,G) forwarding.

Score: 3 Points

---

## Ticket 6

Data MDT (overflow from default MDT): A high-bandwidth multicast stream is consuming excessive bandwidth on the default MDT (shared by all PEs). A data MDT should be triggered to create a dedicated P2MP tunnel for this stream. The threshold is configured but the data MDT never creates.

Fix the network so that the data MDT triggers when the stream exceeds the configured threshold.

Verify: `show ip pim mdt` on the source PE shows a data MDT created for the high-bandwidth stream. The stream moves off the default MDT.

Score: 3 Points

---

## Ticket 7

PIM SSM in the core: The default MDT uses SSM (232.x.x.x range). IGMPv3 is required for SSM but one P router is running IGMPv2 on the MDT-facing interface, preventing proper (S,G) join propagation for the MDT group.

Fix the network so that SSM operates correctly in the core for the MDT group.

Verify: `show ip igmp interface` shows IGMPv3 on all relevant interfaces. `show ip mroute 232.1.1.1` shows (S,G) state on all P routers in the path.

Score: 2 Points

---

## Ticket 8

mLDP-based mVPN (Profile 1, VPN_Mcast_B): The mLDP P2MP LSP is not being established for the default MDT. LDP sessions between P routers are operational (unicast labels working) but multipoint LDP opaque values are not being processed.

Fix the network so that the mLDP P2MP tree is established for VPN_Mcast_B's default MDT.

Verify: `show mpls mldp database` shows the P2MP tree with all PE leaves. `show ip pim mdt` for VPN_Mcast_B shows the MDT tunnel interface UP.

Score: 3 Points

---

## Ticket 9

RPF (Reverse Path Forwarding) check failure in the VRF: Multicast traffic from R21 arrives at PE R9 but is dropped due to RPF failure. The unicast route to the source exists in the VRF routing table, but the multicast traffic arrives on a different interface than the unicast route points to.

Fix the network so that RPF succeeds for multicast traffic from R21 in VPN_Mcast_B.

Verify: `show ip rpf vrf VPN_Mcast_B <source-IP>` shows the correct RPF interface matching where traffic arrives. `show ip mroute vrf VPN_Mcast_B` shows no RPF failures.

Score: 2 Points

---

## Ticket 10

Multicast traffic is flowing correctly from source to receiver, but the receiver is getting DUPLICATE packets. The same multicast stream arrives via both the default MDT and a data MDT simultaneously, causing double delivery.

Fix the network so that only one copy of each multicast packet reaches the receiver.

Verify: Packet capture on R22 shows exactly one copy of each packet. `show ip mroute vrf VPN_Mcast_A` shows clean (S,G) state without dual paths.

Score: 2 Points

---

## Ticket 11

IGMP snooping on a PE-CE segment is incorrectly filtering multicast traffic. The receiver (R23) sends IGMP joins but the PE interface does not see them because an intermediate L2 switch (simulated) is consuming the IGMP reports.

Fix the network so that the PE receives IGMP joins from the receiver and creates appropriate mroute state.

Verify: `show ip igmp groups vrf VPN_Mcast_A` on the PE shows the group membership for R23. Multicast traffic is forwarded to R23.

Score: 3 Points

---

## Ticket 12

Extranet multicast: A multicast source in VPN_Mcast_A (239.1.1.1) should be receivable by a receiver in VPN_Mcast_B. Route leaking for unicast between VRFs is configured but multicast RPF in the receiving VRF cannot validate the source because it's in a different VRF.

Fix the network so that multicast extranet forwarding works between VPN_Mcast_A and VPN_Mcast_B.

Verify: Receiver in VPN_Mcast_B receives the multicast stream from VPN_Mcast_A's source. `show ip mroute vrf VPN_Mcast_B` shows (S,G) state with the cross-VRF source.

Score: 3 Points

---

## Ticket 13

PIM Assert on the CE segment: Two PEs are connected to the same CE LAN segment for the VPN. Both PEs are forwarding multicast to the segment, causing duplicate traffic. PIM Assert should resolve this, but both PEs continue forwarding.

Fix the network so that PIM Assert elects a single forwarder on the multi-homed CE segment.

Verify: Only one PE forwards multicast to the CE segment. `show ip pim interface` shows assert winner elected. No duplicate packets on the CE LAN.

Score: 4 Points

---

## Ticket 14

mVPN with BGP auto-discovery (Type 3/Type 7 routes): A PE is not generating the BGP auto-discovery route (Type 3 — S-PMSI A-D route) for a high-rate stream. Without this route, remote PEs don't know to join the data MDT. Traffic stays on the overloaded default MDT.

Fix the network so that the source PE generates the correct BGP mVPN route to trigger data MDT joins.

Verify: `show ip bgp ipv4 mdt all` shows Type 3 route from the source PE. Remote PEs join the data MDT.

Score: 4 Points

---

## Ticket 15

mLDP in-band signaling: VPN_Mcast_B uses mLDP with in-band signaling (no MDT). The P2MP tree label mapping is incorrect — leaf PEs are receiving traffic but the label at the root is being swapped to an invalid outgoing label at a midpoint P router.

Fix the network so that the mLDP label forwarding is correct end-to-end.

Verify: `show mpls mldp forwarding` shows correct label operations at each hop. Multicast traffic reaches all leaf PEs via the mLDP P2MP tree.

Score: 4 Points

---

## Ticket 16

Multicast traffic black-hole during PE failover: A dual-homed receiver loses multicast after its primary PE fails. The backup PE has VRF state but the upstream (S,G) join across the core does not switch to the backup PE. Receiver has no traffic for 60+ seconds.

Fix the network so that multicast fails over to the backup PE within a few seconds.

Verify: Simulate primary PE failure — receiver gets multicast from backup PE within 5 seconds. `show ip mroute vrf` on backup PE shows active (S,G) forwarding.

Score: 4 Points

---

## Ticket 17

Core PIM state explosion: Each PE multicast VRF source is creating (S,G) state on EVERY P router in the core, even P routers not on the shortest path. The core mroute table has grown to thousands of entries, consuming memory and CPU. Only on-path P routers should maintain state.

Fix the network so that only P routers in the actual forwarding path maintain multicast state.

Verify: `show ip mroute count` on off-path P routers shows minimal state. On-path P routers show only relevant (S,G) entries. Memory utilization decreases.

Score: 4 Points

---

## Ticket 18

Complete mVPN failure for VPN_Mcast_A: Source R20 sends to 239.1.1.1 but NO receiver in the VPN receives traffic. Investigation shows:
- PE R1 has (S,G) state locally in the VRF
- Default MDT tunnel interface shows UP
- Core PIM shows MDT group state
- But traffic never reaches remote PEs

Multiple issues exist in the multicast forwarding path.

Fix ALL issues so that multicast flows end-to-end in VPN_Mcast_A.

Verify: All receivers (R22, R23, R24) receive the 239.1.1.1 stream. `show ip mroute vrf VPN_Mcast_A` on all PEs shows active (S,G) state.

Score: 5 Points

---

## Ticket 19

Multicast with anycast RP in the VRF: Two PEs act as anycast-RP for VPN_Mcast_B (MSDP between them). After a network event, MSDP peering is broken and sources registered on one RP are invisible to receivers joined on the other RP. Multicast is partitioned.

Fix the network so that anycast-RP with MSDP provides a unified multicast domain across both RPs.

Verify: Sources registered on either RP are known to both. Receivers on either RP's domain receive all sources. `show ip msdp sa-cache` shows active source entries.

Score: 5 Points

---

## Ticket 20

Multi-failure across both mVPN profiles:
- VPN_Mcast_A (GRE MDT): Default MDT UP but data plane drops — GRE encap MTU issue
- VPN_Mcast_B (mLDP): P2MP tree established but wrong root — source traffic enters at wrong PE
- Core PIM: Partial connectivity — one P router not forwarding MDT traffic (RPF failure in core)
- BGP mdt SAFI: Stale routes from a decommissioned PE causing phantom joins

Fix ALL multicast issues across both VPN profiles.

Verify: VPN_Mcast_A sources reach all receivers (no fragmentation drops). VPN_Mcast_B sources reach all receivers via correct mLDP tree. Core forwarding clean. No phantom state.

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
