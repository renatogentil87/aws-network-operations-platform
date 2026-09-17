# CCIE SP Workbook 05 — L3VPN PE-CE Routing Protocols

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. PEs + P + ASBRs + CEs.
**Initial configs:** Workbook 04 complete — VRFs, MP-BGP VPNv4 via RRs, VPN_A working with eBGP PE-CE.

> **Note:** VPN_A is your working L3VPN. This workbook cycles the PE-CE protocol through every option the exam tests — eBGP (with same-AS pitfalls), OSPF (with the DN bit and domain-id), EIGRP, RIP, and static — and the redistribution/loop issues each introduces.

---

## Section 1 — eBGP PE-CE and the Same-AS Problem

### Task 1.1
- Customer A uses **AS 65001 at both sites** (CE1 and CE3). Show that CE3 rejects CE1's routes by default, then fix it with **AS-override** on the PEs.
- Prove bidirectional reachability afterward.

**Configuration**

eBGP's AS-path loop prevention rejects any route whose AS-path already contains the receiver's own ASN — so with the same AS at both customer sites, each CE drops the other's prefixes. `as-override` on the PE rewrites the customer ASN in the AS-path with the provider ASN before advertising to the CE, defeating the loop check so the far CE accepts the routes. The side effect: you have now *disabled* the natural loop protection — which is exactly why SoO is required in Section 3 for multi-homed sites.

**Verification**
- Before: `show ip bgp vpnv4 vrf VPN_A` on CE3 lacks CE1's prefixes (AS-path loop).
- After `as-override`: prefixes present; AS-path shows provider AS replacing 65001; CE1↔CE3 ping works.

---

## Section 2 — OSPF PE-CE

### Task 2.1
- Reconfigure the CE3 site to use **OSPF (process 2) in VRF VPN_A, area 0** between PE3 and CE3.
- On PE3, mutually redistribute between OSPF 2 and BGP under the VRF.
- Confirm CE1 (still eBGP) reaches CE3 (OSPF) and inspect how the route appears at CE3.

**Configuration**

With OSPF PE-CE, the MP-BGP core acts as a **super-backbone**. Routes crossing PE→MP-BGP→PE are carried as VPNv4 and re-originated into OSPF on the far PE. Whether they appear as inter-area (type-3) or external (type-5) depends on the **OSPF domain-id** and the BGP extended communities (domain-id, route-type, router-id) attached during redistribution. Matching domain-ids across PEs makes the routes appear as inter-area summaries rather than externals — preserving intra-domain semantics for the customer.

### Task 2.2
- Verify the **DN (Down) bit** is set on LSAs the PE injects into the customer OSPF, and explain the loop it prevents.

**Configuration**

When a PE redistributes an MP-BGP-learned route into OSPF, it sets the **DN bit** in the LSA. Any PE that receives an OSPF LSA with the DN bit set must **not** redistribute it back into MP-BGP. Without this, a route learned from the core, re-advertised into OSPF, and picked up by another PE on the same VRF could loop back into VPNv4 — a control-plane loop. The DN bit is OSPF's equivalent of the SoO/AS-override safety net, specifically for multi-PE OSPF sites.

**Verification**
- `show ip ospf database external <prefix>` / `... summary` on CE3 — DN bit visible.
- `show ip route vrf VPN_A` on CE3 — CE1's routes as O IA (or O E2 depending on domain-id).
- CE1 ↔ CE3 reachability confirmed.

---

## Section 3 — SoO and Multi-Homing Loop Prevention

### Task 3.1
- Multi-home CE1 to a second PE. Because `as-override` is active, demonstrate the routing loop risk, then apply **Site-of-Origin (SoO)** `64500:1` on both PEs' PE-CE sessions to CE1.
- Prove SoO blocks a PE from re-advertising CE1's own routes back to CE1's site while preserving reachability to other sites.

**Configuration**

`as-override` removed eBGP's AS-path loop protection, so a route originated by CE1, carried through the core, and learned by CE1's *other* PE could be advertised back to CE1 — a loop. **SoO** tags each route with the originating *site* identifier; a PE will not advertise a route back out to a site carrying the same SoO. Crucially SoO only suppresses the site's *own* routes returning to it — every other destination still reaches CE1 via both PEs, so multi-homing/failover is preserved. SoO is the companion fix to as-override (and the analog of the OSPF DN bit).

**Verification**
- `show ip bgp vpnv4 vrf VPN_A <CE1-prefix>` — SoO extended community present.
- On the second PE: CE1's own routes are NOT advertised back to CE1; routes to CE3 still are.
- Ping tests confirm reachability intact, no loop.

---

## Section 4 — EIGRP, RIP, and Static PE-CE

### Task 4.1
- Convert the CE5 site (VPN_C) to **EIGRP** PE-CE; preserve EIGRP metrics/topology across the core using the EIGRP BGP cost-community/SoO handling.
- Convert the CE6 site (VPN_D) to **static** PE-CE with redistribution into BGP.
- (Optional) Add a **RIP** PE-CE variant on a spare interface.

**Configuration**

EIGRP PE-CE uses BGP extended communities to carry EIGRP-specific attributes (AS, metric vector, hop count) across the VPNv4 core so the far site sees native EIGRP internal/external routes with sane metrics; SoO again prevents multi-homed EIGRP loops. Static PE-CE is the simplest option — a static route in the VRF pointing at the CE, redistributed into BGP, and a default/static on the CE — used where the customer runs no dynamic protocol. Each protocol needs its own redistribution and loop-prevention story, which is the core skill this section drills.

**Verification**
- EIGRP: `show ip eigrp vrf VPN_C topology` at CE5 shows core-learned routes with preserved metrics.
- Static: `show ip route vrf VPN_D` shows the redistributed static; CE6 reachable.
- All customers isolated; each PE-CE protocol independently functional.

---

## CCIE Challenge Tasks

### Challenge A — Mixed-protocol customer
- Make one customer run eBGP at one site and OSPF at another, and guarantee optimal routing plus loop-freeness across the mixed edge. Document the redistribution direction and metrics.

### Challenge B — BGP cost community
- Use the BGP **cost community** (pre-bestpath / point) to influence route selection for a backdoor scenario before the more elegant OSPF sham-link fix in Workbook 06.

### Challenge C — Redistribution safety audit
- For every VRF, verify no mutual-redistribution loop exists (DN bit / SoO / down-bit filtering all correct) and that no customer can leak into another. Produce a short "loop-prevention matrix" in your notes.
