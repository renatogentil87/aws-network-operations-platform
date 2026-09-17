# CCIE SP Workbook 06 — Advanced L3VPN (Sham-Link, Shared Services, Inter-AS)

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. PEs + P + ASBRs + CEs. Inter-AS section splits the core into two ASes.
**Initial configs:** Workbooks 04–05 complete — multi-VRF L3VPN with mixed PE-CE protocols and loop prevention.

> **Note:** This is the advanced L3VPN workbook — the designs real SPs deploy for enterprises: OSPF sham-links, shared-services/extranet route leaking, per-VRF Internet access, and Inter-AS Options A/B/C. Highest-difficulty L3VPN content.

---

## Section 1 — OSPF Sham-Link

### Task 1.1
- Customer A (OSPF PE-CE, area 0) has a **backdoor link** directly between CE1 and CE3.
- Show that both CEs prefer the backdoor (intra-area) over the VPN path (inter-area/external), even though the backdoor is the intended backup.
- Configure a **sham-link** between PE1 and PE3 (sourced from VRF loopbacks advertised via BGP, not OSPF) so the VPN path is preferred; verify failover to the backdoor when the core is cut.

**Configuration**

Routes crossing the MPLS VPN core arrive at the far PE as OSPF inter-area (type-3) or external (type-5) — always *less preferred* than an intra-area route across a direct backdoor link. So OSPF wrongly prefers the slow backdoor. A **sham-link** is a logical intra-area OSPF adjacency between the two PEs, tunneled over MP-BGP, that makes the VPN path appear **intra-area** — restoring correct preference. Its endpoints are VRF loopbacks advertised into the VRF **via BGP, not OSPF** (otherwise they'd recurse). SPF uses the sham-link for path selection while actual forwarding still rides the MP-BGP-learned labels across the core.

**Verification**
- Before sham-link: `show ip route vrf VPN_A` on CE3 shows CE1 via the backdoor (O intra-area).
- After sham-link: `show ip ospf sham-links` up; CE3 now prefers the VPN path (intra-area via sham-link).
- Cut the core: traffic fails over to the backdoor; restore core: returns to VPN path.

---

## Section 2 — Shared Services & Extranet

### Task 2.1
- Create a **Shared_Services** VRF (RD `64500:999`) on PE2 hosting two server loopbacks.
- Grant VPN_A and VPN_B access to shared services **without** letting VPN_A and VPN_B reach each other (a hub-of-services / star, not any-to-any).

**Configuration**

Controlled inter-VRF access is pure RT engineering. The Shared_Services VRF exports 64500:999; VPN_A and VPN_B each add `import 64500:999` to receive the servers. For the servers to reply, Shared_Services imports 64500:100 and 64500:200. Because VPN_A never imports 64500:200 (and vice-versa), the two customers still cannot see each other — the topology is a star centered on shared services. This is the RT-as-access-control pattern.

### Task 2.2
- Implement a **one-way extranet**: leak only a single DNS host (a /32) from VPN_A into VPN_B, nothing else, using an **export-map** that adds the target RT to just that prefix.
- Add the return-path leak so the ping actually works, and prove all other prefixes stay isolated.

**Configuration**

An export-map with a prefix-list matches the specific /32 and attaches an *additional* RT (VPN_B's import RT) to only that route, so exactly one prefix crosses the boundary. Two subtleties the exam loves: (1) the export-map only applies at export time — after changing it you must soft-clear BGP to re-export existing routes; (2) one-way leaking gets the route *to* the client but the server can't reply until you leak the client's source prefix back — a functional extranet is bidirectional for the specific host pair, isolated for everything else. Watch for address collisions when a leaked /32 overlaps an existing address in the target VRF.

**Verification**
- `show ip bgp vpnv4 all <DNS-/32>` — carries BOTH RTs; the non-shared prefixes carry one.
- VPN_B CE reaches the DNS host but nothing else in VPN_A; VPN_A cannot reach VPN_B.
- `show ip route vrf Shared_Services` — sees VPN_A and VPN_B; customers don't see each other.

---

## Section 3 — Per-VRF Internet Access

### Task 3.1
- Provide Internet access to VPN_A only, via a default route injected from the global table (or a dedicated Internet VRF), while keeping other customers without Internet and still isolated from each other.

**Configuration**

Common approaches: (a) a static default in the VRF pointing at a global next-hop with the `global` keyword, redistributed into the VRF's BGP; or (b) a dedicated Internet VRF whose default is imported only by customers who bought Internet. Either way, only VPN_A receives 0.0.0.0/0, and Internet reachability does **not** create inter-customer reachability — each customer's Internet path is independent and isolated. This is the SP's per-customer Internet product.

**Verification**
- `show ip route vrf VPN_A` shows 0.0.0.0/0; VPN_B/C/D do not.
- VPN_A CE reaches a simulated Internet prefix; VPN_B cannot; customers remain mutually isolated.

---

## Section 4 — Inter-AS L3VPN (Options A / B / C)

### Task 4.1 — Option A (back-to-back VRF)
- Split the core into **AS 64500 (north)** and **AS 64501 (south)** with ASBRs on the P6/PE-boundary. Interconnect VPN_A across the ASes using per-VRF eBGP subinterfaces between ASBRs.

### Task 4.2 — Option B (VPNv4 eBGP at ASBRs)
- Replace Option A with **VPNv4 eBGP between ASBRs** (next-hop-self, label swap at the boundary), with RT filtering on the ASBRs.

### Task 4.3 — Option C (multihop VPNv4 + labeled BGP)
- Implement **Option C**: RRs exchange VPNv4 multihop across ASes while ASBRs exchange PE loopbacks via **BGP labeled unicast (send-label)**, so the end-to-end LSP spans both ASes.

**Configuration**

The three options trade scalability for ASBR simplicity. **Option A** is simplest (plain eBGP per VRF at the boundary, unlabeled) but requires a subinterface/VRF per customer on the ASBRs — it doesn't scale. **Option B** carries VPNv4 directly between ASBRs; the ASBR rewrites next-hop and swaps VPN labels, so per-customer config moves off the boundary, but the ASBR holds all VPNv4 state. **Option C** keeps the ASBRs free of VPNv4 entirely — they only exchange labeled /32 loopbacks (BGP-LU) so a single end-to-end LSP crosses both ASes, while multihop VPNv4 runs RR-to-RR. Option C scales best and is what large carriers use to interconnect. The exam expects you to configure and contrast all three.

**Verification**
- End-to-end CE reachability across the two ASes in each option.
- Option A: unlabeled IP on the inter-AS link (per-VRF). Option B: `show bgp vpnv4 unicast` on ASBR shows VPNv4 with swapped labels. Option C: `show bgp ipv4 unicast labels` on ASBRs shows labeled loopbacks; ASBRs hold no VPNv4.
- `traceroute`/label inspection confirms one end-to-end LSP in Option C.

---

## CCIE Challenge Tasks

### Challenge A — Carrier Supporting Carrier (CSC)
- Build a CSC scenario where your SP is the backbone carrier for a customer carrier: use **BGP labeled unicast (send-label)** on the PE-CE link so the customer carrier's internal labels transit your core (three-label stack). Verify the label stack depth.

### Challenge B — Full isolation matrix
- With 4 customers + shared services simultaneously, design and prove the complete RT import/export matrix: every customer reaches shared services bidirectionally, no customer reaches another. Document the ~12 RT values.

### Challenge C — Inter-AS Option C failure analysis
- In the Option C design, fail an ASBR and analyze convergence: which layer (BGP-LU loopback LSP vs multihop VPNv4) reconverges, and how BGP PIC/best-external (Workbook 11) would accelerate it.
