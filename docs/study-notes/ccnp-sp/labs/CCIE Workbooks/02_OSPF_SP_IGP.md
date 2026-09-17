# CCIE SP Workbook 02 — OSPF as the Service Provider IGP

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. See 00_Base for role mapping.
**Initial configs:** Base interface addressing only. (Alternative IGP to Workbook 01 — run one at a time.)

> **Note:** This workbook uses OSPF as the core IGP instead of IS-IS, to master OSPF-specific behavior (LSA types, area design, path selection) that the exam still tests. Load base addressing; no IGP configured yet. Global table only.

---

## Section 1 — Backbone Area 0

### Task 1.1
- Configure OSPF process 1 on all core and PE routers, all core links and Loopback0s in **area 0**.
- Set the OSPF **router-id** to Loopback0 on every node.
- Advertise loopbacks as OSPF **point-to-point** so they appear as /32 (not /32-with-host quirk) — and set core links to network type point-to-point.

**Configuration**

A single-area OSPF backbone is the simplest resilient SP core for fewer than ~200 routers. Forcing the router-id to the loopback stabilizes identity across interface flaps. Setting core links to point-to-point network type suppresses DR/BDR election (unnecessary on routed P2P links) and removes the type-2 network LSA, reducing LSDB size and speeding SPF. Loopbacks advertised as point-to-point are injected as a /32 host route — critical because that /32 is the LSP endpoint / BGP next-hop later; leaving the default loopback behavior can advertise them in a way that complicates MPLS next-hop resolution.

**Verification**
- `show ip ospf neighbor` — FULL on every core link (no 2-WAY, since P2P suppresses DR/BDR).
- `show ip ospf database` — router LSAs (type-1) only on core links; no network LSAs (type-2).
- `show ip route ospf | include 10.0.0.` — all loopbacks present as /32.

---

## Section 2 — Multi-Area Design & LSA Behavior

### Task 2.1
- Convert the south core (P2, P4, P6, PE5, PE6) into **area 2**, with P4 as the ABR.
- Keep the north core + RRs in area 0.
- Ensure full reachability and identify each LSA type crossing the ABR.

**Configuration**

Introducing an ABR partitions the LSDB: intra-area type-1/2 LSAs stay within their area, and the ABR generates type-3 summary LSAs to advertise one area's prefixes into another. This is the scaling lever — SPF runs per area, so a topology change in area 2 no longer forces area 0 routers to re-run full SPF, only to reprocess summaries. The tradeoff is that inter-area routes lose full topology detail (they become distance-vector-like at the ABR), which can create suboptimal paths that Task 2.2 addresses.

### Task 2.2
- Summarize area 2's loopback range at the ABR (P4) toward area 0 with a single `area range`.
- Explain the impact on MPLS: why an over-aggressive summary would break LDP/BGP next-hop resolution for PE5/PE6.

**Configuration**

`area range` on the ABR replaces the individual /32s with one summary, shrinking the area-0 LSDB and RIB. But MPLS transport needs an LSP to each **exact /32** egress PE loopback (BGP next-hops resolve to /32s, and LDP by best practice labels only /32 host routes). If the ABR summarizes PE5/PE6's loopbacks into a covering aggregate, the specific /32 disappears from area 0, LDP has no host-route to label, and VPNv4 next-hop resolution fails → black-hole. The SP rule: summarize customer/aggregation prefixes, but never summarize PE/RR loopbacks that serve as LSP endpoints. This is the OSPF analog of the /32 discipline you enforce in IS-IS.

### Task 2.3
- Make area 2 a **totally NSSA** except you must still carry the PE5/PE6 loopbacks as /32.
- Reconcile the conflict between "totally stubby" (blocks type-3/5) and needing the specific loopbacks.

**Configuration**

A totally NSSA blocks type-3 summaries and type-5 externals, injecting only a default route — great for reducing an edge area's table, but it destroys the specific /32 LSP endpoints MPLS needs. The reconciliation is either (a) not making the area totally stubby for the loopback prefixes (leak the specific /32s back in via `area range`/`no-summary` exceptions or a not-so-totally-stubby carve-out), or (b) keeping PE loopbacks in area 0. This task forces you to confront that aggressive OSPF stub optimizations and MPLS /32 requirements are in tension — the same lesson as the IS-IS overload/leaking challenge.

**Verification**
- `show ip ospf database summary` — type-3 LSAs for area 2 prefixes on area-0 routers; single summary after Task 2.2.
- `show mpls forwarding-table 10.0.0.5` on a north PE — an LSP to PE5's /32 exists (proves the summary didn't hide it).
- End-to-end `traceroute mpls ipv4 10.0.0.6/32` succeeds.

---

## Section 3 — Path Selection

### Task 3.1
- Engineer PE1→PE3 to prefer the north chain using OSPF cost (adjust `auto-cost reference-bandwidth` consistently, then per-interface cost) — without changing link bandwidth.
- Demonstrate ECMP by making two end-to-end paths equal-cost and confirm per-flow load-balancing.

**Configuration**

OSPF selects the lowest cumulative cost, where cost = reference-bw / interface-bw by default. The reference bandwidth must be set identically network-wide (e.g., `reference-bandwidth 100000`) or high-speed links are indistinguishable and cost math breaks. ECMP occurs when total end-to-end cost is equal — not when individual links match — so you engineer equal *cumulative* cost across diverse paths, and CEF then load-balances per-flow. This is the OSPF equivalent of the IS-IS wide-metric engineering in Workbook 01.

**Verification**
- `show ip ospf interface <intf> | include Cost` — costs reflect the reference bandwidth.
- `show ip route 10.0.0.3` — two equal-cost next-hops when ECMP is engineered.
- `show ip cef 10.0.0.3 internal` — per-flow hashing across both paths.

---

## CCIE Challenge Tasks

### Challenge A — Sham-link prerequisite awareness
- Note where in area design an OSPF **PE-CE** deployment would need a sham-link (covered fully in Workbook 06) and why the core being a *different* OSPF process/area from the customer matters.

### Challenge B — Fast convergence
- Tune SPF/LSA throttling (`timers throttle spf`, `timers throttle lsa`), enable **BFD** and **OSPF LFA/rLFA**; measure sub-second convergence on a core link failure.

### Challenge C — OSPF vs IS-IS for SP
- In your notes, contrast why most large SPs chose IS-IS (protocol-independent, TLV extensibility for SR, fewer LSA types) over OSPF for the core — tying back to Workbook 01.
