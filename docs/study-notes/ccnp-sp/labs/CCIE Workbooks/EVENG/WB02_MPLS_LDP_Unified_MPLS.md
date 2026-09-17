# CCIE SP Workbook 02 — MPLS LDP & Unified MPLS

**Domain 1: Core Routing (25%)**
**Platform:** IOS-XRv 9000

---

## Topology Reference

**Emerald — AS 65100 (IS-IS + LDP)**

| Node | Loopback0 | Role |
|------|-----------|------|
| PCE1 | 6.6.6.6 | Path Computation Element |
| P2 | 4.4.4.4 | Core P |
| P1 | 3.3.3.3 | Core P |
| ASBR1 | 5.5.5.5 | Inter-AS border |
| PE1 | 1.1.1.1 | Edge PE |
| PE2 | 2.2.2.2 | Edge PE |

**Garnet — AS 65200 (IS-IS + SR-MPLS)**

| Node | Loopback0 | Role |
|------|-----------|------|
| PCE | 17.17.17.17 | Path Computation Element |
| P3–P5 | — | Core P |
| ASBR2 | 16.16.16.16 | Inter-AS border |
| PE3 | 11.11.11.11 | Edge PE |
| PE4 | 12.12.12.12 | Edge PE |

**Gold — AS 65300 (IS-IS + SRv6)**

| Node | Loopback0 | Role |
|------|-----------|------|
| ASBR3 | 21.21.21.21 | Inter-AS border |
| ASBR4 | 22.22.22.22 | Inter-AS border |
| P6 | 23.23.23.23 | Core P |
| PE5 | 24.24.24.24 | Edge PE |
| PE6 | 25.25.25.25 | Edge PE |

**Inter-AS links:**
- ASBR1 ↔ ASBR2 (direct, Emerald ↔ Garnet)
- ASBR1 ↔ ASBR3 (Emerald ↔ Gold)
- ASBR4 ↔ ASBR2 (Gold ↔ Garnet)

**Inter-AS addressing convention used in this workbook:**

| Link | A-side | B-side |
|------|--------|--------|
| ASBR1 ↔ ASBR2 | 10.100.200.5/30 (ASBR1 Gi0/0/0/2) | 10.100.200.6/30 (ASBR2) |
| ASBR1 ↔ ASBR3 | 10.100.300.5/30 (ASBR1 Gi0/0/0/3) | 10.100.300.21/30 (ASBR3 Gi0/0/0/1) |
| ASBR4 ↔ ASBR2 | 10.300.200.22/30 (ASBR4 Gi0/0/0/2) | 10.300.200.16/30 (ASBR2 Gi0/0/0/1) |

---

## Section 1 — LDP Basics on Emerald

### Task 1.1: LDP Neighbor Discovery (5 points)

**Question:** On the Emerald core, enable LDP on all IS-IS core interfaces so that P1 (3.3.3.3), P2 (4.4.4.4), ASBR1 (5.5.5.5), PE1 (1.1.1.1), and PE2 (2.2.2.2) form LDP adjacencies. Use the interface-level `mpls ldp` model. Verify that link-hello (UDP 646) discovery brings up sessions over TCP 646.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.2: Targeted LDP Session (5 points)

**Question:** PE1 (1.1.1.1) and PE2 (2.2.2.2) are not directly connected but require a directed LDP session (e.g., for a future L2VPN/AToM pseudowire). Configure a **targeted** LDP session between PE1 and PE2 without relying on link hellos.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.3: LDP Router-ID from Loopback0 (5 points)

**Question:** Ensure every Emerald LSR derives a **deterministic** LDP router-ID and transport address from its `Loopback0` interface, so that LDP IDs match the IS-IS/BGP loopbacks (e.g., PE1 = 1.1.1.1, P1 = 3.3.3.3). Prevent the router from auto-selecting an arbitrary interface address.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.4: Label Allocation Filtering — Host Routes Only (5 points)

**Question:** Reduce LFIB size on the Emerald core. Configure LDP so each LSR only **allocates/originates** local labels for **/32 host routes** (loopbacks), not for the intra-area transit links. Use a prefix-list.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.5: LDP Session Protection (5 points)

**Question:** On P1 (3.3.3.3), protect the LDP sessions so that if a directly connected link goes down but the neighbor is still reachable via an alternate IGP path, the **label bindings are retained** and the session survives via a targeted hello. Hold retained bindings for 120 seconds.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 2 — LDP Advanced

### Task 2.1: LDP Authentication (MD5) (5 points)

**Question:** Secure the LDP TCP sessions on the ASBR1 (5.5.5.5) ↔ P1 (3.3.3.3) link with **MD5 authentication**. Configure it symmetrically.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 2.2: LDP Graceful Restart (5 points)

**Question:** Enable **LDP Graceful Restart (GR)** on PE1 (1.1.1.1) and its core neighbor P1 (3.3.3.3) so that an LDP control-plane restart (e.g., RP failover) does not tear down the forwarding path. Set forwarding-state hold and reconnect timers appropriately.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 2.3: LDP-IGP Synchronization Verification (5 points)

**Question:** LDP-IGP sync is configured on the Emerald IS-IS core. On the P2 (4.4.4.4) ↔ P1 (3.3.3.3) link, **disable `mpls ldp` on the P1 end** to simulate an LDP-not-ready condition, and verify that IS-IS advertises the **maximum metric** for that link until LDP re-synchronizes.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 2.4: LDP Label Advertisement Filtering — PE Loopbacks Only (5 points)

**Question:** On the Emerald core, configure LDP so that each LSR only **advertises** labels for the **PE loopbacks PE1 (1.1.1.1/32) and PE2 (2.2.2.2/32)** to its neighbors — not for P/ASBR/PCE loopbacks. Use advertise (outbound) filtering.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 3 — BGP Labeled Unicast / Unified MPLS

### Task 3.1: BGP-LU Concept for Inter-AS (5 points)

**Question:** Explain, and then set the stage for, **BGP Labeled Unicast (BGP-LU / RFC 3107)** as the inter-AS transport mechanism for **Unified MPLS (Seamless MPLS)** across Emerald → Gold → Garnet. Why is BGP-LU needed instead of extending LDP across the AS boundaries?


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 3.2: BGP-LU between ASBR1 ↔ ASBR3 (Emerald ↔ Gold) (5 points)

**Question:** Configure eBGP **labeled-unicast** between ASBR1 (Emerald AS 65100, 5.5.5.5) and ASBR3 (Gold AS 65300, 21.21.21.21) over the inter-AS link (ASBR1 10.100.300.5, ASBR3 10.100.300.21). Advertise Emerald PE loopbacks (1.1.1.1/32, 2.2.2.2/32) toward Gold with labels, and set next-hop-self so the label path stitches at the border. eBGP peering is over the directly connected interface addresses.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 3.3: BGP-LU between ASBR4 ↔ ASBR2 (Gold ↔ Garnet) (5 points)

**Question:** Configure eBGP **labeled-unicast** between ASBR4 (Gold AS 65300, 22.22.22.22) and ASBR2 (Garnet AS 65200, 16.16.16.16) over the inter-AS link (ASBR4 10.300.200.22, ASBR2 10.300.200.16). Propagate the Emerald PE loopbacks (learned from Task 3.2) onward into Garnet with labels, and have ASBR2 set next-hop-self so Garnet SR-MPLS resolves the transit. Also advertise Garnet PE3 (11.11.11.11/32) back toward Gold.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 3.4: End-to-End Label Path PE1 → (Gold transit) → PE3 (5 points)

**Question:** Verify and explain the **end-to-end Unified MPLS label path** from PE1 (Emerald, 1.1.1.1) to PE3 (Garnet, 11.11.11.11) transiting the **Gold** AS via the ASBR1→ASBR3 and ASBR4→ASBR2 stitches. Ensure PE1 has a labeled route to 11.11.11.11/32 and trace the label operations at each hop.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 4 — Troubleshooting

### Task 4.1: LDP Session Down — Transport Address Mismatch (5 points)

**Question:** On the ASBR1 (5.5.5.5) ↔ P1 (3.3.3.3) link, LDP **discovery** shows hellos being exchanged, but the session never reaches `Oper` (stuck initializing / no TCP). No MD5 is configured. Diagnose and fix.

**Symptom / Diagnosis:**

```
show mpls ldp discovery
! Hellos Xmit/Recv present, but:
show mpls ldp neighbor brief
! Session state = "Initialized" / never "Oper"
show tcp brief | include :646
! No established TCP 646 to the peer's expected address
```

Root cause: a **transport-address mismatch**. One end advertises a `discovery transport-address` (or interface address) that is **not reachable / not in the IGP** by the peer, or the two ends disagree on which address to open the TCP session to (e.g., P1 set `discovery transport-address 3.3.3.3` but 3.3.3.3/32 is not advertised into IS-IS, so ASBR1 cannot open TCP to it). LDP hellos are UDP and still succeed, but the TCP 646 session fails because the transport address is unroutable.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 4.2: Label Not in LFIB — Allocation Filtering Too Aggressive (5 points)

**Question:** After applying the label allocation filter from Task 1.4, traffic to a specific PE loopback **PE2 (2.2.2.2/32)** is being IP-forwarded (unlabeled) on part of the Emerald core, and `show mpls forwarding` on P1 has **no entry** for 2.2.2.2/32. LDP sessions are up. Diagnose and fix.

**Symptom / Diagnosis:**

```
show mpls ldp bindings 2.2.2.2/32
! No local binding on P1 -> label was never allocated
show mpls forwarding prefix 2.2.2.2/32
! No LFIB entry
show run formal | include "prefix-list|allocate for"
```

Root cause: the **allocation prefix-list is too aggressive** — it does not match 2.2.2.2/32 (e.g., the prefix-set was written as `0.0.0.0/0 eq 32` but was accidentally scoped to specific hosts like only `1.1.1.1/32`, or a `le/ge` bound excludes it). Because no **local label** is allocated for the FEC, P1 has nothing to advertise or install, and forwarding for that prefix falls back to plain IP.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 4.3: BGP-LU Next-Hop Not Resolvable (5 points)

**Question:** On ASBR2 (Garnet, 16.16.16.16), the Emerald PE prefix 1.1.1.1/32 is present in the BGP-LU table but is marked **not usable** — it is not installed in the RIB/CEF and not re-advertised into Garnet. The eBGP-LU session to ASBR4 is up. Diagnose and fix.

**Symptom / Diagnosis:**

```
show bgp ipv4 labeled-unicast 1.1.1.1/32
! Path present but "(inaccessible)" / "not advertised" / next hop not resolved
show bgp ipv4 labeled-unicast 1.1.1.1/32 | include "next hop|inaccessible|not"
show route <bgp-next-hop>
! The BGP next hop has no route
```

Root cause: the **BGP next-hop is not resolvable / not label-reachable**. Because ASBR4 did **not** apply `next-hop-self` (or the inter-AS /30 link address it left as next hop isn't redistributed into Garnet's IGP, and there is no label to it), ASBR2 has no resolving route+label to the next hop. BGP requires the next hop to be reachable **and, for labeled-unicast transit, label-reachable**; an unresolvable next hop makes the route unusable and unadvertised.


> *Try this yourself first. Solution available in `solutions/` folder.*

