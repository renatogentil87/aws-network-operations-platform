# CCIE SP Workbook 04 — MPLS L3VPN (MP-BGP VPNv4)

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. PEs + P + ASBRs + CEs.
**Initial configs:** Workbooks 01 (or 02) and 03 complete — IGP converged, LDP LSPs between all PE loopbacks, host-route label optimization in place.

> **Note:** The transport is ready (loopback LSPs exist). This workbook adds the VPN service layer: VRFs, MP-BGP VPNv4 with route reflectors, and the two-label forwarding that isolates customers over the shared core.

---

## Section 1 — First VPN, Two Sites

### Task 1.1
- On PE1 and PE3, create VRF **VPN_A** with RD `64500:100`, route-target import/export `64500:100`.
- Place the CE1-facing interface (PE1) and CE3-facing interface (PE3) into VPN_A.
- Configure the PE-CE links and CE loopbacks; CE1 and CE3 are **Customer A, AS 65001**.

**Configuration**

A VRF gives each customer an independent routing/forwarding table on the PE. The **Route Distinguisher** is prepended to the IPv4 prefix to form a 96-bit VPNv4 NLRI, making otherwise-overlapping customer addresses unique in BGP — the RD is about *uniqueness*, and is part of the prefix. The **Route Target** is a separate extended community that governs *import/export policy* — which VRFs receive the route. RD ≠ RT: change the RD and routes become distinct NLRIs; the RT still controls who imports them. This distinction is the backbone of everything in Workbooks 05–06.

### Task 1.2
- Configure **MP-BGP VPNv4** so X-PE1 and X-PE3 exchange VPN_A routes **via RRs X-PE1/X-PE2** (do not peer PEs directly).
- Ensure the IPv4 address-family is **not** activated by default on those sessions.
- Result: CE1 and CE3 reach each other's connected/loopback prefixes.

**Configuration**

PEs peer with the redundant RRs for the `vpnv4 unicast` address-family only; leaving IPv4-unicast deactivated keeps the global table off the VPN sessions. The RR reflects VPNv4 NLRIs between PE clients, so you avoid an n² PE full-mesh. Forwarding uses a **two-label stack**: the outer transport label (from LDP, to the egress PE loopback) carries the packet across the BGP-free core; the inner VPN label (assigned by MP-BGP) tells the egress PE which VRF/CE to hand the packet to. P routers switch only the transport label and never see the VPN label or customer routes.

**Verification**
- `show ip bgp vpnv4 all summary` on PE1 — two neighbors (RR1, RR2), VPNv4 activated.
- `show ip route vrf VPN_A` on PE3 — CE1's prefixes present, next-hop = PE1 loopback.
- `show ip bgp vpnv4 vrf VPN_A <prefix>` — two labels shown (in/out), RT 64500:100.
- CE1 → CE3 ping succeeds; `traceroute` from CE1 shows the two-label stack in the core.

---

## Section 2 — Isolation, Scale, and the RD/RT Model

### Task 2.1
- Add VRF **VPN_B** (RD/RT `64500:200`) on PE2 and PE4 for **Customer B, AS 65002** (CE2, CE4).
- Prove complete isolation: VPN_A CEs cannot reach VPN_B CEs and vice-versa, and neither VRF's RIB contains the other's routes.

**Configuration**

Isolation is a pure consequence of RT policy: VPN_A imports only 64500:100, VPN_B only 64500:200, so their VPNv4 routes never cross-import. Even if two customers use identical RFC1918 space, the distinct RDs keep them as separate NLRIs in BGP and the distinct RTs keep them in separate VRFs. This is the fundamental multi-tenant property of MPLS L3VPN — one shared core, mathematically enforced separation.

### Task 2.2
- Give PE2 and PE4 each a **unique RD per PE** for VPN_B (e.g., `64500:20002` on PE2, `64500:20004` on PE4) while keeping RT `64500:200`.
- Multi-home CE2 to a second PE and prove the RRs now reflect **both** paths (no path hiding), where a shared RD would have hidden one.

**Configuration**

An RR runs best-path and reflects only its single best path per NLRI. With a **shared RD**, two PEs advertising the same customer prefix are the *same* NLRI, so the RR hides one path — killing multipath and fast failover for a multi-homed site. Assigning a **unique RD per PE** makes the two advertisements *different* NLRIs; the RR can no longer collapse them and reflects both. The receiving PE imports both (same RT) and finally has two paths to choose from. Rule: **change the RD (identity), keep the RT (policy).** This unlocks Add-Path/PIC-style fast convergence in Workbook 11.

**Verification**
- `show ip route vrf VPN_A` has zero VPN_B prefixes (and vice-versa).
- Before unique RD: `show ip bgp vpnv4 all <CE2-prefix>` at the far PE shows ONE path.
- After unique RD: the same command shows **two** VPNv4 NLRIs (different RD) resolving to two next-hops.

---

## Section 3 — Data-Plane Deep Dive

### Task 3.1
- Trace the label operations for a CE1→CE3 packet hop-by-hop: PUSH (two labels) at PE1, transport SWAP through P routers, PHP at penultimate, VPN-label lookup + VRF forwarding at PE3.
- On PE3, confirm the VPN label shows `in/out: <label>/nolabel` and explain why the outgoing is nolabel.

**Configuration**

At the egress PE the VPN label's outgoing action is `nolabel` (aggregate/`untagged`) because the next hop is a directly-connected CE — no further label is needed; the PE pops the VPN label, does a VRF IP lookup, and forwards natively to the CE. Meanwhile the transport label was already popped one hop earlier by PHP. This confirms the "expensive work at the edge, dumb fast core" division: exactly two IP lookups in the whole path (ingress VRF, egress VRF); everything between is label switching.

**Verification**
- `show ip cef vrf VPN_A <CE3-prefix> detail` on PE1 — both imposed labels listed.
- On a P router: `show mpls forwarding-table` — only the transport label is swapped; VPN label invisible.
- `show ip bgp vpnv4 vrf VPN_A <prefix>` on PE3 — `mpls labels in/out … /nolabel`.

---

## CCIE Challenge Tasks

### Challenge A — Per-prefix vs per-VRF label mode
- Switch VPN_A to `mpls label mode vrf VPN_A protocol bgp-vpnv4 per-prefix`, clear BGP, and show each prefix now carries a unique VPN label. Explain when per-prefix is needed (per-prefix TE / accounting) vs the default aggregate mode.

### Challenge B — RT-Constrain (RFC 4684)
- Enable the `rtfilter` address-family on the RRs and PEs. Prove that PE5 (only VPN_C) stops receiving VPN_A/VPN_B routes, and that adding a VPN_A import on PE5 dynamically pulls them back. Explain the scalability win on a 1000-VRF network.

### Challenge C — Label churn on reset
- Clear the PE1↔RR VPNv4 session and observe whether the VPN label for a prefix changes; quantify the brief data-plane impact and relate it to why graceful-restart/NSR matters for VPN services.
