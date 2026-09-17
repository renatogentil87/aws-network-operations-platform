# CCIE SP Workbook 01 — IS-IS as the Service Provider IGP

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. See `00_Base_Topology_and_Index.md` for role mapping.
**Initial configs:** Interfaces addressed per the base plan (loopbacks 10.0.0.X/32, core links 10.1.AB.0/30). No IGP configured yet.

> **Note:** Load the base interface addressing before starting. IS-IS is the target IGP for the entire SP core and PE loopbacks. All work is in the global table.

---

## Section 1 — Single Level-2 Backbone

### Task 1.1
- Configure IS-IS on all core and PE routers as a single **Level-2-only** backbone.
- Use NET `49.0001.0100.0000.00XX.00`, where XX is the two-digit node number.
- Advertise every core link and every Loopback0 into IS-IS.
- Use **wide metrics** (metric-style wide) exclusively.
- By the end, every router must have a Level-2 adjacency on each core link and reach every Loopback0.

**Configuration**

Service provider cores almost universally run IS-IS as a single Level-2 flooding domain rather than OSPF, for three practical reasons. First, IS-IS runs directly over the data link (it is not carried in IP), so it is protocol-agnostic and trivially extends to IPv6 and to Segment Routing SIDs via new TLVs without a redesign. Second, its two-level hierarchy and TLV-based encoding scale cleanly to hundreds of nodes with less LSA/LSP churn than OSPF's LSA types. Third, `metric-style wide` removes the legacy 6-bit (0–63) narrow metric limit and enables the 32-bit sub-TLVs that TE and SR later depend on — which is why it is mandatory here even before any TE is configured.

Level-2-only is chosen because a flat backbone avoids L1/L2 route leaking and the attendant suboptimal routing until you explicitly need areas. Each router's NET encodes an area (49.0001) and a system-ID derived from the node number; the system-ID must be unique and stable, so it is bound to the node, not an interface.

### Task 1.2
- Set all core interfaces to **point-to-point** IS-IS network type.
- Ensure Loopback0 is advertised as a **passive** interface (no adjacencies formed on it).

**Configuration**

On point-to-point links, IS-IS elects no DIS and uses a simpler 2-way adjacency with no pseudonode LSP — this reduces LSP count and speeds convergence versus broadcast (LAN) behavior, which would otherwise elect a DIS and generate a pseudonode. Explicitly setting `point-to-point` on routed core links is a standard SP hardening step. Passive-interface on Loopback0 advertises the /32 into the LSP without wasting hellos or forming a spurious adjacency, and it is that /32 that becomes the LSP endpoint for LDP/BGP next-hop resolution later.

**Verification**
- `show isis neighbors` — every core link shows a Level-2 adjacency in the "UP" state.
- `show isis database detail` — each router originates one LSP; no pseudonode LSPs exist (confirms point-to-point).
- `show ip route isis | include 10.0.0.` — all 14 core/PE loopbacks are reachable.
- `traceroute` between two PE loopbacks — path follows lowest cumulative wide metric.

---

## Section 2 — Metrics, Authentication, and Stability

### Task 2.1
- Engineer the core so the path PE1→PE3 prefers the P1–P3–P5 chain over P2–P4–P6.
- Do NOT change interface bandwidth; use IS-IS interface metrics only.

**Configuration**

IS-IS wide metrics are per-interface and directional, so path engineering is done by raising the metric on the links you want to deprecate rather than by touching bandwidth (which would have QoS and other side effects). Because SPF selects the lowest cumulative metric, you influence the whole backbone's view by adjusting a small number of links — but you must reason about the cumulative sum end-to-end, not per-hop, and remember that asymmetric metrics can produce asymmetric forwarding.

### Task 2.2
- Secure all IS-IS adjacencies and LSP flooding with **HMAC-MD5 authentication** using key `INE-SP`.
- Apply it at both the interface (hello) and the area/domain (LSP) level.

**Configuration**

IS-IS supports authentication at two scopes: hello authentication (per interface, protects adjacency formation) and LSP/SNP authentication (per level, protects the flooding of the link-state database). A common exam trap is authenticating only hellos, leaving LSP flooding unauthenticated — an attacker could still inject LSPs. Both must be configured, and because IS-IS floods LSPs domain-wide, a mismatched key silently breaks the database on part of the network while adjacencies stay up, so roll keys carefully.

### Task 2.3
- Configure P4 to set the **overload bit** on startup for 180 seconds.
- Explain (in your notes) why this matters when P4 also runs BGP.

**Configuration**

The overload bit (originally "hippity" / router-is-overloaded) tells the rest of the domain "do not use me as a transit path" while still allowing me to reach directly-connected prefixes. On a router that is also a BGP speaker, set-overload-on-startup with a timer prevents a freshly-rebooted node from attracting transit traffic through the core before BGP has converged and installed the full table — otherwise you black-hole traffic that IS-IS forwards to a node whose BGP RIB is not yet ready. This is the IS-IS analog of BGP's wait-for-convergence and pairs conceptually with LDP-IGP sync.

**Verification**
- `show isis database detail <P4>` — LSP shows the overload bit set for the first 180s after reload.
- `traceroute` PE-to-PE during that window — transit avoids P4 but P4's own connected routes remain reachable.
- `show isis neighbors detail` — authentication is active; a deliberately mismatched key drops the adjacency.

---

## CCIE Challenge Tasks

### Challenge A — Multi-level with route leaking
- Split the south core (P2, P4, P6, PE5, PE6) into **Level-1 area 49.0002**; keep the north as L2.
- Make P4 the L1/L2 border. Ensure PE5's loopback is reachable from PE1 with an optimal path, using **route leaking** (not a default route) so the L1 area still makes intelligent exit decisions.
- Verify the L1/L2 attached-bit behavior and prove that leaking specific L2 prefixes into L1 fixes the suboptimal-exit problem a plain default route would cause.

### Challenge B — Fast convergence
- Tune **IS-IS SPF and PRC throttling** and enable **BFD** on all core adjacencies.
- Measure convergence on a core link failure with a continuous ping; target sub-second, then document the detection-vs-computation split.

### Challenge C — Prepare the core for Segment Routing
- Confirm `metric-style wide` everywhere and that every Loopback0 is a /32.
- Explain in your notes why these two conditions are prerequisites for enabling SR-MPLS in Workbook 09 (wide-metric sub-TLVs carry the prefix-SID; the /32 host route is the LSP endpoint the SID maps to).
