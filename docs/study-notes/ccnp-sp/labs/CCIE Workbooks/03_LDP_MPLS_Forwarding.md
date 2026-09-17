# CCIE SP Workbook 03 — LDP & MPLS Forwarding

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. See 00_Base for role mapping.
**Initial configs:** Workbook 01 complete (IS-IS L2 backbone, all loopbacks reachable).

> **Note:** LDP is enabled on the IGP-converged core from Workbook 01. All work is in the global table; no VRFs yet. This workbook builds the label-switched transport that every VPN service in later workbooks rides on.

---

## Section 1 — Baseline LDP

### Task 1.1
- Enable **LDP** on every core-facing interface of P1–P6, PE1–PE6, RR1–RR2.
- Force each router's **LDP router-id** to its Loopback0 with the `force` keyword.
- By the end, there must be a full mesh of directly-connected LDP sessions and an end-to-end LSP between every pair of PE loopbacks.

**Configuration**

LDP builds label-switched paths by piggybacking on the IGP: for every prefix the IGP installs, each LSR allocates a local label and advertises it to its LDP peers, so an LSP is formed hop-by-hop toward each IGP destination. Because the LDP session's transport address and router-id default to an interface address that can flap, SP best practice is to pin the LDP router-id to the stable Loopback0 with `force`; the `force` keyword is required to change it after the session is already up. The LSP that matters is the one to each egress PE's /32 loopback, because that is the transport tunnel the VPN label will later ride inside.

### Task 1.2
- Verify the **two-operation** label behavior across the core: PUSH at ingress PE, SWAP through P routers, POP at the penultimate hop (PHP).
- Confirm which label value signals PHP.

**Configuration**

Every labeled packet undergoes exactly one of PUSH, SWAP, or POP. The ingress PE pushes a transport label toward the egress PE loopback; each P router swaps it for the next-hop's label via its LFIB with no IP lookup; and the penultimate router pops the label because the egress advertised **implicit-null (label 3)** for its own FEC — telling upstream "don't send me a labelled packet, I'd only have to pop it and do a lookup anyway." PHP saves the egress a second lookup. (Explicit-null, label 0, is the alternative used when EXP/QoS bits must be preserved to the egress.)

**Verification**
- `show mpls ldp neighbor` — full mesh of `Oper` sessions; peer IDs are loopbacks.
- `show mpls forwarding-table 10.0.0.3` — the FEC for PE3's loopback shows Push/Swap actions.
- On the penultimate P router: `show mpls forwarding-table 10.0.0.3` shows outgoing label **Pop Label** (implicit-null received from PE3).
- `traceroute mpls ipv4 10.0.0.3/32` from PE1 — validates the LSP end-to-end (not just IP reachability).

---

## Section 2 — Label Space Optimization & Protection

### Task 2.1
- Restrict LDP so it only allocates/advertises labels for **/32 host routes (loopbacks)** — not for the /30 core links.
- Confirm customer/global forwarding is unaffected.

**Configuration**

By default IOS LDP allocates a label for every IGP prefix, including every /30 transit link — pure waste, because the only FECs that ever need an LSP are the LSP endpoints (PE/RR loopbacks used as BGP next-hops). Filtering allocation to host routes (`mpls ldp label allocate global host-routes`, or an ACL on `mpls ldp advertise-labels for`) shrinks the LFIB/LIB and reduces LDP churn on link flaps. Forwarding is unaffected because /30 links are transit — traffic rides the loopback LSP and is IP-forwarded or label-switched over the links, which never needed their own label. **Caveat:** every LSP endpoint must remain a covered /32 and must not be lost to summarization, or BGP next-hop resolution breaks and VPN traffic black-holes.

### Task 2.2
- Enable **LDP Session Protection** between all directly-connected core neighbors.
- Prove that a core link flap (where an alternate IGP path exists) does not tear down the LDP session or flush labels.

**Configuration**

Normally an LDP session is bound to the link's link-local discovery; if the link drops, the session drops, labels are flushed, and on recovery the session must re-establish and re-exchange every binding — a forwarding gap. Session protection adds a **targeted LDP session to the peer's loopback** alongside the link-local one. Because the targeted session is reachable via any IGP path, it survives a direct-link failure as long as an alternate path exists, preserving all label bindings for seamless recovery. A configurable duration/hold-timer governs how long to hold before giving up.

### Task 2.3
- Enable **LDP-IGP synchronization** on all IS-IS core interfaces.
- Demonstrate the failure it prevents: disable `mpls ip` on one link that IS-IS still prefers, and show traffic being forwarded unlabeled (which would black-hole an L3VPN).

**Configuration**

The IGP and LDP converge independently, so the IGP can start using a link before LDP has exchanged labels on it — forwarding unlabeled IP where a label is required. In an L3VPN that means the egress PE receives a packet with no VPN label and cannot select the VRF → black-hole. LDP-IGP sync makes the IGP advertise **max-metric** on any MPLS-enabled interface where LDP is not yet operational, steering traffic to a labelled alternate until LDP is ready, then reverting automatically. Principle: the control plane must never route traffic onto a link where the label plane is not ready.

**Verification**
- `show mpls forwarding-table` — labels exist only for /32 loopbacks after Task 2.1.
- `show mpls ldp neighbor detail` — targeted "session protection" adjacency present; flap a protected link and confirm the session stays `Oper`.
- After disabling `mpls ip` on a preferred link: `traceroute mpls`/`show ip cef` shows unlabeled forwarding; enabling `mpls ldp sync` restores labelled forwarding by max-metricing the link until LDP is up.

---

## CCIE Challenge Tasks

### Challenge A — TTL & core hiding
- Configure `no mpls ip propagate-ttl` on the ingress PEs and show that a customer traceroute across the core collapses the P-router hops into a single hop. Explain the security/opacity rationale.

### Challenge B — MTU and the label stack
- Compute the effective payload reduction for a two-label stack (transport + VPN) and set `mpls mtu` on core links to avoid fragmentation/PMTUD failures for 1500-byte customer frames. Prove it with large pings + DF bit.

### Challenge C — Convergence chain
- With a continuous PE-to-PE ping, fail a core link and decompose the recovery into: IGP detection → IGP SPF → LDP label update → LFIB reprogramming. Note where LDP session protection and liberal label retention shorten the chain, and where the IGP dominates.
