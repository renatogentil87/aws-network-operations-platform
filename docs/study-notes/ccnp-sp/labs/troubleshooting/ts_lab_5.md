# Troubleshooting Lab 5: L2VPN & VPLS — 20 Tickets

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 16 routers — 4 PEs (R1, R5, R9, R13), 4 P routers, 8 CEs (L2 attached)
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change MPLS core or IGP configuration unless explicitly required
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
| P | R2, R3, R6, R10 | — |
| RR | R3, R10 | 64512 |
| CE | R20-R27 (Layer-2 attached customers) |

**L2VPN Services:**
- VPWS_100: Point-to-point EoMPLS — R20 (on R1) ↔ R22 (on R5)
- VPWS_200: Point-to-point EoMPLS — R21 (on R1) ↔ R23 (on R9)
- VPLS_300: Multipoint VPLS — R24 (R1), R25 (R5), R26 (R9), R27 (R13)
- H-VPLS_400: Hierarchical VPLS — R13 as hub, R1/R5/R9 as spokes

**Signaling:** LDP-based VPLS (RFC 4762) and targeted LDP for VPWS
**Core:** OSPF area 0, LDP on all P/PE links, full mesh LSPs

---

## Ticket 1

VPWS_100: The pseudowire between R1 and R5 for VC-ID 100 is not establishing. Both PEs can ping each other's loopbacks. The targeted LDP session between them is missing.

Fix the network so that the targeted LDP session establishes and the pseudowire comes UP.

Verify: `show mpls l2transport vc 100` on both R1 and R5 shows status UP.

Score: 2 Points

---

## Ticket 2

VPWS_100: The pseudowire shows "UP" in control plane status but the attachment circuit on one PE shows "DOWN." The physical interface connected to the CE is UP/UP. L2 traffic between R20 and R22 fails.

Fix the network so that the attachment circuit is UP and traffic flows.

Verify: `show mpls l2transport vc 100 detail` shows both local and remote status as UP. `ping` between R20 and R22 succeeds.

Score: 2 Points

---

## Ticket 3

VPWS_200: The pseudowire between R1 and R9 shows status "Standby" on R9's side. Only one direction of the pseudowire is active. R1's side shows UP.

Fix the network so that the pseudowire is active on both endpoints.

Verify: `show mpls l2transport vc 200` on both R1 and R9 shows status UP (not Standby).

Score: 2 Points

---

## Ticket 4

VPLS_300: R1 has joined the VPLS instance (VFI configured), but it shows 0 peers discovered. R5, R9, and R13 have formed a partial mesh with each other in VPLS_300.

Fix the network so that R1 has full VPLS peering with all other PEs in VPLS_300.

Verify: `show vfi name VPLS_300` on R1 shows 3 peers (R5, R9, R13) with signaling status UP.

Score: 3 Points

---

## Ticket 5

VPLS_300: All four PEs show full peering, but MAC learning is broken. R24 (attached to R1) cannot reach R25 (attached to R5). The pseudowire is UP, but frames are not being forwarded. The bridge domain shows 0 learned MAC addresses.

Fix the network so that MAC learning occurs and L2 traffic flows within VPLS_300.

Verify: `show bridge-domain 300` on R1 shows learned MAC addresses. `ping` between R24 and R25 (same VLAN/subnet) succeeds.

Score: 3 Points

---

## Ticket 6

VPLS_300: A broadcast storm is occurring. R26 (attached to R9) is flooding traffic that loops back through the VPLS mesh. MAC table on all PEs shows flapping MAC addresses. Split-horizon is apparently not working.

Fix the network so that split-horizon prevents L2 loops within the VPLS instance.

Verify: `show bridge-domain 300` shows stable MAC addresses (no flapping). No broadcast storm. Traffic flows correctly between all CEs.

Score: 3 Points

---

## Ticket 7

VPWS_100: MTU mismatch between the two PEs. The pseudowire negotiation is failing with an "MTU mismatch" error in the LDP status. One PE has a 1500-byte MTU and the other has 9000 bytes configured on the attachment circuit.

Fix the network so that the MTU matches and the pseudowire establishes.

Verify: `show mpls l2transport vc 100 detail` shows matching MTUs and status UP.

Score: 2 Points

---

## Ticket 8

VPLS_300: One PE (R13) is in the VPLS instance but is using a different VPN-ID/VPLS-ID than the others. The targeted LDP sessions form but the FEC elements don't match, so no pseudowires establish between R13 and the other PEs.

Fix the network so that R13's VPLS-ID matches the rest of the VPLS instance.

Verify: `show vfi name VPLS_300` on R13 shows 3 peers with signaling UP. `ping` from R27 to R24/R25/R26 succeeds.

Score: 3 Points

---

## Ticket 9

H-VPLS_400: The hub (R13) and spoke (R1) pseudowire is UP but the spoke PE is NOT flooding BUM traffic to the hub. R1's locally attached CE can reach other local CEs but cannot reach CEs attached to R5 or R9 (which connect through the hub).

Fix the network so that BUM traffic from the spoke traverses the hub and reaches all H-VPLS sites.

Verify: `ping` from CE on R1 to CE on R5 (through the H-VPLS hub) succeeds.

Score: 2 Points

---

## Ticket 10

VPWS_200: Traffic works for untagged frames, but 802.1Q-tagged frames from the CE are being dropped by the pseudowire. The CE sends tagged frames (VLAN 50) but they never arrive at the remote CE.

Fix the network so that tagged frames are transported transparently across the pseudowire.

Verify: Tagged frames (VLAN 50) from R21 arrive at R23 with the VLAN tag intact. `show mpls l2transport vc 200 detail` shows correct encapsulation type.

Score: 2 Points

---

## Ticket 11

VPLS_300: MAC address table on R5 is full (reached the configured limit). New MAC addresses from R25 are not being learned, causing traffic to R25 to be flooded continuously. The MAC table limit is set too low.

Fix the network so that the MAC table limit is appropriate and R25's MACs are learned.

Verify: `show bridge-domain 300` on R5 shows R25's MAC addresses learned. Unicast traffic to R25 is switched (not flooded).

Score: 3 Points

---

## Ticket 12

VPLS_300: Spanning Tree BPDUs from a CE are leaking into the VPLS core and causing pseudowire flapping. One CE is running STP and its BPDUs are being transported to other CEs, triggering topology changes across the VPLS domain.

Fix the network so that STP BPDUs are filtered at the PE edge without disrupting the VPLS service.

Verify: `show spanning-tree` on remote CEs does NOT show the originating CE's bridge. Pseudowires remain stable.

Score: 3 Points

---

## Ticket 13

VPWS_100: The pseudowire is UP and forwarding traffic, but the control word is not being negotiated. This causes packet reordering issues and ECMP load-balancing in the MPLS core is hashing poorly (all traffic on one path). The PE on one side has `control-word` configured and the other does not.

Fix the network so that the control word is negotiated and active on the pseudowire.

Verify: `show mpls l2transport vc 100 detail` shows "control word enabled" on both PEs. Traffic is load-balanced across available core paths.

Score: 4 Points

---

## Ticket 14

VPLS_300 with PW redundancy: R1 has a primary and backup pseudowire to the VPLS instance. The primary PW has failed (remote PE down), but the backup PW is NOT activating. Traffic to/from R24 is completely dead.

Fix the network so that the backup pseudowire activates when the primary fails.

Verify: `show mpls l2transport vc detail` on R1 shows the backup PW in active/UP state. R24 has connectivity to other VPLS members.

Score: 4 Points

---

## Ticket 15

H-VPLS_400: Dual-homed spoke with active/standby pseudowires to two hub PEs. Both pseudowires show active (no standby). This is causing a MAC flapping loop as both hub PEs forward traffic for the same spoke CE.

Fix the network so that only ONE spoke pseudowire is active and the other is in standby.

Verify: `show mpls l2transport vc detail` — one PW shows active, the other standby. No MAC flapping in `show bridge-domain` logs.

Score: 4 Points

---

## Ticket 16

VPWS_200 with QoS: An ingress policy-map on the attachment circuit is marking traffic and shaping to 50 Mbps. After the pseudowire transport, the egress PE is dropping the QoS markings. EXP bits in the MPLS label are all zero, and the egress PE delivers all traffic as best-effort.

Fix the network so that QoS markings are preserved end-to-end across the pseudowire.

Verify: Traffic from R21 arrives at R23 with correct DSCP markings. `show policy-map interface` on egress confirms traffic is classified correctly.

Score: 4 Points

---

## Ticket 17

VPLS_300 with MAC withdrawal: After a topology change (one PE goes down and comes back), stale MAC entries persist on remote PEs for 300+ seconds. Traffic destined to those MACs is being sent to the old (incorrect) PE until the MAC ages out.

Fix the network so that MAC withdrawal messages are sent upon topology change, clearing stale MACs immediately.

Verify: Simulate a PE flap — remote PEs clear the affected MAC entries within seconds (not 300s). `show bridge-domain 300` confirms MAC entries are refreshed.

Score: 4 Points

---

## Ticket 18

Complete VPLS_300 failure: NO CE can reach any other CE in the VPLS instance. Investigation shows:
- VFI configuration exists on all PEs
- Targeted LDP sessions are established between all PE pairs
- Pseudowires show UP in `show mpls l2transport`
- Bridge domain shows no MAC addresses learned

Multiple root causes exist simultaneously.

Fix ALL issues so that full L2 connectivity is restored in VPLS_300.

Verify: All CEs (R24, R25, R26, R27) can ping each other. MAC addresses are learned correctly on all PEs.

Score: 5 Points

---

## Ticket 19

Interworking scenario: VPWS_100 needs to bridge between an Ethernet attachment circuit on R1 and a VLAN-tagged (dot1q) attachment circuit on R5. Currently, frames arrive at the remote end with incorrect encapsulation — either double-tagged or stripped of the tag the remote CE expects.

Fix the network so that L2 interworking correctly translates between the two encapsulation types.

Verify: Untagged frames from R20 arrive at R22 with the expected VLAN tag. Tagged frames from R22 arrive at R20 untagged. Bidirectional traffic works.

Score: 5 Points

---

## Ticket 20

Multi-service failure:
- VPWS_100: Pseudowire UP but data plane black-hole (labels incorrect)
- VPWS_200: Control plane down (targeted LDP session won't establish)
- VPLS_300: Partial mesh — one PE excluded
- H-VPLS_400: Hub PE forwarding correctly but spoke PE has wrong split-horizon behavior

Fix ALL four L2VPN services simultaneously.

Verify: All L2VPN services pass traffic. VPWS_100 (R20↔R22), VPWS_200 (R21↔R23), VPLS_300 (all-to-all), H-VPLS_400 (all spokes through hub).

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
