# CCIE SP Workbook 09 — Segment Routing (SR-MPLS, TI-LFA, SR-TE, Flex-Algo)

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology (SR concepts; full SR-TE needs XRv later)
**Topology:** Two ASes per `gns3_base_topology.md`. SR focus on AS Y (IS-IS).
**Initial configs:** IS-IS L2 backbone with **wide metrics** and /32 loopbacks (Workbook 01). No LDP required — SR replaces it.

> **Note:** Segment Routing replaces LDP/RSVP-TE. The IGP (IS-IS) distributes labels as SIDs; there is no separate label-distribution protocol. Wide metrics and /32 loopbacks (from Workbook 01) are prerequisites. All work on IOS-XR.

---

## Section 1 — SR-MPLS Foundation (Prefix-SIDs)

### Task 1.1
- Enable **Segment Routing MPLS** under IS-IS on all core/PE nodes.
- Set a common **SRGB 16000–23999**; assign each Loopback0 a **prefix-SID index = node number** (PE1 = index 1 → label 16001, etc.).
- Achieve end-to-end reachability using SR labels only — with **no LDP** anywhere.

**Configuration**

SR uses the MPLS data plane but distributes labels through the IGP: each node advertises a globally-significant **prefix-SID** for its loopback inside IS-IS (via SR sub-TLVs, which is why wide metrics were mandatory). The **SRGB** is the reserved label range, identical on every node so that prefix-SID 16001 means "reach PE1" *everywhere* — globally significant, unlike LDP's locally-significant labels. To reach a destination on the shortest path the head-end pushes a **single** prefix-SID; transit routers forward it via their own IGP SPF. This eliminates LDP entirely: one protocol (IS-IS) does routing *and* label distribution.

**Verification**
- `show isis segment-routing label table` — all prefix-SIDs present, consistent SRGB.
- `show mpls forwarding` — labels 16001…160xx installed; **no LDP** (`show mpls ldp neighbor` empty).
- `ping`/`traceroute` PE-to-PE over SR labels; label value for a given loopback is identical on every hop.

### Task 1.2
- Examine **adjacency-SIDs** on a chosen node and explain their (locally-significant) role vs prefix-SIDs.

**Configuration**

Adjacency-SIDs are locally-significant labels each node auto-allocates per IGP adjacency; they identify a *specific link* rather than a destination. A label stack of [adj-SID, adj-SID, …] is pure **source routing** — the head-end dictates the exact hop-by-hop path, and transit nodes are stateless. Prefix-SIDs (global, shortest-path) + adjacency-SIDs (local, specific link) are the two primitives SR-TE composes into explicit paths.

**Verification**
- `show isis segment-routing adjacency-sid` — per-neighbor adj-SIDs.
- Build a manual label stack in a traceroute/policy and confirm it follows the exact links.

---

## Section 2 — TI-LFA Fast Reroute

### Task 2.1
- Enable **TI-LFA** (`fast-reroute per-prefix ti-lfa`) on all IS-IS core interfaces.
- Prove sub-50ms protection: continuous CE-to-CE traffic, fail a primary core link, count 0–1 lost packets. Then test **node** protection.

**Configuration**

TI-LFA pre-computes, for every destination, a backup path expressed as a **segment list**, using the post-convergence topology — and pre-installs it in the FIB. On failure, hardware switches to the repair path in <50ms, before the IGP even reconverges. Because the repair is a label stack, TI-LFA is **topology-independent** — it always finds a loop-free backup, even in topologies where classic LFA/rLFA could not, and it protects every prefix automatically with zero per-transit state (unlike RSVP-TE FRR's pre-signaled backup tunnels).

**Verification**
- `show isis fast-reroute summary` / `... <prefix> detail` — backup path with repair segment list pre-computed.
- `show cef <loopback> detail` — primary + backup next-hop installed.
- Link/node failure test: 0–1 packet loss; compare to the multi-second loss without TI-LFA.

---

## Section 3 — SR-TE Policies

### Task 3.1
- Create an **explicit SR-TE policy** on PE1 steering traffic to PE3 via a non-shortest path (specific P nodes), using a segment-list of prefix-SIDs.
- Create a **dynamic** SR-TE policy (metric IGP/latency) and observe automatic recomputation on metric change.

**Configuration**

An SR-TE policy encodes the path as a label stack on the head-end — there is **no tunnel state** on transit routers (the fundamental win over RSVP-TE). An explicit policy uses an operator-defined segment-list; a dynamic policy runs constrained SPF (locally or via PCE) and installs the resulting stack. Traffic is steered into a policy by **color + endpoint**, decoupling "what path" from "which prefixes." Transit P routers just pop/forward the top SID — stateless, scalable.

**Verification**
- `show segment-routing traffic-eng policy` — policy UP, segment-list installed.
- `traceroute` follows the engineered path, not shortest path.
- Change an IGP metric: dynamic policy recomputes automatically.

### Task 3.2
- Steer **L3VPN (VPNv4)** traffic into an SR-TE policy using **BGP color** extended community (On-Demand Next-hop / ODN).

**Configuration**

ODN auto-creates an SR-TE policy when a BGP VPN route arrives with a matching **color** community, to the BGP next-hop, using the color's constraints — no per-prefix tunnel config. This replaces RSVP-TE `autoroute` with flexible, color-based, per-service steering, and scales to thousands of VPN prefixes because policies are created on demand.

**Verification**
- `show segment-routing traffic-eng policy` shows an ODN-created policy per color/endpoint.
- `show cef vrf <vrf> <prefix>` resolves via the SR-TE policy; traceroute confirms the engineered path.

---

## Section 4 — Flex-Algo & Migration

### Task 4.1
- Define **Flex-Algo 128 (min-delay)** and **129 (TE-metric)**; advertise per-algorithm prefix-SIDs; steer latency-sensitive traffic via Algo 128.

**Configuration**

Flex-Algo lets each node compute multiple constrained topologies (by delay, TE-metric, or SRLG/affinity exclusion) and advertise a **separate prefix-SID per algorithm**. Pushing the Algo-128 SID steers a packet along the lowest-latency topology; the default SID follows IGP cost — same physical network, multiple logical topologies, **no tunnels and no transit state**. This is intent-based TE ("give me the low-latency plane") at massive scale.

### Task 4.2
- Demonstrate **SR-LDP interworking** (a Mapping Server) so an SR island can interoperate with a legacy LDP island during migration.

**Configuration**

A **SID Mapping Server** advertises prefix-SIDs on behalf of LDP-only nodes, letting SR and LDP coexist and stitch during a phased migration — the standard "ships-in-the-night then remove LDP" path real SPs use. This is how you migrate a production core from LDP to SR without a flag day.

**Verification**
- `show isis flex-algo` — Algo 128/129 defined; per-algo prefix-SIDs advertised.
- Traffic with the Algo-128 SID follows the min-delay path.
- Mapping-server: `show segment-routing mapping-server prefix-sid-map` maps the LDP island's prefixes.

---

## CCIE Challenge Tasks

### Challenge A — PCE-delegated SR-TE
- Delegate SR-TE policy computation to a **stateful PCE** (PCEP) with BGP-LS feeding topology. Show the head-end delegating and the PCE computing/updating paths centrally.

### Challenge B — TI-LFA + microloop avoidance
- Enable microloop avoidance and prove it eliminates transient loops during convergence after a link restoration; correlate with the TI-LFA repair path.

### Challenge C — SRv6 (if image supports)
- Convert a VPN service to **SRv6** (locators, End/End.DT4 SIDs) and contrast the MPLS-free data plane with SR-MPLS. Note where CCIE-SP weights SR-MPLS more heavily.
