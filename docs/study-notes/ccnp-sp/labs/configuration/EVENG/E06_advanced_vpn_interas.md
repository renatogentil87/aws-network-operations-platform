# E06: Advanced VPN — Inter-AS Options A/B/C

**Platform:** IOS-XRv 9000 on GNS3/EC2
**Topology:** `00_topology_reference.md` — Emerald AS 65100 ↔ Garnet AS 65200
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3
**Prerequisite:** E02 complete (L3VPN VPNv4 in both ASes).

**End Goal:** Inter-AS L3VPN Options A, B, and C between E-R6 (Gi0/0/0/0) ↔ Gar-R7 (Gi0/0/0/1), joining Customer A (CE1/CE2 in Emerald ↔ CE4 in Garnet). Plus SoO, extranet/shared-services, and sham-link concept.

> Configure and verify one option at a time, then roll back before the next (snapshot between options). Interface: E-R6 Gi0/0/0/0 ↔ Gar-R7 Gi0/0/0/1.

---

## Section 1: Option A (back-to-back VRF)

### Task 1: VRF-to-VRF over the inter-AS link
1. On E-R6: sub-interface(s)/VRF CUST_A toward Gar-R7 with PE-CE-style eBGP per VRF. Mirror on Gar-R7.
2. Each ASBR treats the other as a CE; RT import/export local to each AS.
3. Verify: `show bgp vrf CUST_A` on both ASBRs — customer prefixes exchanged.
4. Verify: CE1 ↔ CE4 ping succeeds. Note scaling cost (per-VRF interface).
5. Snapshot **"E06-optionA"**, then roll back.

---

## Section 2: Option B (VPNv4 eBGP between ASBRs)

### Task 2: eBGP VPNv4 E-R6↔Gar-R7
1. `router bgp` → `address-family vpnv4 unicast`, eBGP neighbor across Gi0/0/0/0↔Gi0/0/0/1 (loopback or link peering with `next-hop-self`/label rewrite).
2. `retain route-target all` (or route-policy) on ASBRs so VPNv4 routes aren't dropped for absent local RTs.
3. ASBR rewrites VPN label at the AS boundary (no per-VRF interfaces).
4. Verify: `show bgp vpnv4 unicast` on ASBRs — cross-AS VPNv4 prefixes with rewritten labels.
5. Verify: CE1 ↔ CE4 ping succeeds; confirm no VRF interface on the inter-AS link.
6. Snapshot **"E06-optionB"**, then roll back.

---

## Section 3: Option C (multi-hop VPNv4 + labeled IPv4)

### Task 3: Exchange PE loopbacks with labels between ASes
1. E-R6↔Gar-R7 eBGP `address-family ipv4 labeled-unicast` — advertise PE loopbacks (1.1.1.1/2.2.2.2 ↔ 11.11.11.11/12.12.12.12) with labels.
2. Multi-hop eBGP VPNv4 directly between PEs (or via RRs) — ASBRs carry only labeled transport, not VPNv4.
3. Verify: `show bgp ipv4 labeled-unicast` — remote PE loopbacks + labels present.
4. Verify: end-to-end LSP E-R1→Gar-R1; CE1 ↔ CE4 ping succeeds.
5. Snapshot **"E06-optionC"**.

---

## Section 4: Customer A Joined End-to-End

### Task 4: CE1/CE2 (Emerald) ↔ CE4 (Garnet)
1. Confirm CUST_A RTs aligned across ASes (rewrite/import policy as needed).
2. Verify: full mesh CE1↔CE4 and CE2↔CE4 reachability under the chosen option.

---

## Section 5: Additional Advanced Topics

### Task 5: Site-of-Origin (SoO)
1. Apply `soo 65100:902` on CE2 dual-homed ACs (E-R1 + E-R2) inbound.
2. Verify: prefix learned from one PE is not re-advertised back to the dual-homed site (loop prevention).

### Task 6: Extranet / Shared Services
1. Create a SHARED VRF; import CUST_A RT into SHARED and SHARED RT into CUST_A (selective RT import).
2. Verify: CUST_A reaches shared-services prefix; other customers do not.

### Task 7: Sham-link (concept + optional)
1. Explain: OSPF PE-CE sham-link makes the MPLS backbone appear as an intra-area (O) link instead of inter-area/external, preventing the CE backdoor from being preferred.
2. (Optional) Where an OSPF PE-CE VRF exists (E02 CUST_B/CUST_D), create `sham-link` between PEs and verify route type becomes intra-area.

---

## Section 6: Snapshot
1. Final snapshot: **"E06-interas-complete"**.

---

## Verification Checklist
```
[ ] Option A: back-to-back VRF; CE1↔CE4 works; per-VRF interface noted
[ ] Option B: VPNv4 eBGP E-R6↔Gar-R7 with RT retain + label rewrite; CE1↔CE4 works
[ ] Option C: labeled-unicast PE loopbacks + multi-hop VPNv4; CE1↔CE4 works
[ ] Customer A joined: CE1/CE2 ↔ CE4 end-to-end
[ ] SoO prevents re-advertisement to CE2 dual-homed site
[ ] Extranet/shared-services selective RT import verified
[ ] Sham-link concept documented (optional config verified)
```

---

## Section 3: Gold as Transit Provider (3-way Inter-AS)

### Task 6: Emerald↔Gold inter-AS (E-R6 Gi3 ↔ G-R4 Gi3)
1. Options A/B/C between Emerald and Gold. Customer A: CE1/CE2 (Emerald) ↔ CE8 (Gold).
2. Test: CE1 `ping` CE8 across the Emerald↔Gold boundary.

### Task 7: Gold↔Garnet inter-AS (G-R5 Gi3 ↔ Gar-R7 Gi3)
1. Options A/B/C between Gold and Garnet. Customer B: CE9 (Gold) ↔ CE4 (Garnet).
2. Test: CE9 `ping` CE4 across the Gold↔Garnet boundary.

### Task 8: Transit via Gold (Emerald↔Gold↔Garnet)
1. Traffic from Emerald to Garnet can go DIRECT (E-R6 Gi1 ↔ Gar-R7 Gi1) or via Gold transit.
2. Use BGP LOCAL_PREF or AS-PATH to prefer Gold transit over direct path (or vice versa).
3. Test: traceroute from CE1 to CE4 — which path does it take?

### Task 9: Multi-hop inter-AS (3 AS boundaries)
1. If Customer A had sites in Garnet too (hypothetical): CE1(Emerald) → Gold(transit) → Garnet. Route must cross Emerald→Gold→Garnet = 2 inter-AS hops.
2. This tests Option C with BGP-LU stitching across multiple ASes.

### Updated Checklist
```
[ ] Emerald↔Garnet direct (E-R6 Gi1 ↔ Gar-R7 Gi1) — Options A/B/C
[ ] Emerald↔Gold (E-R6 Gi3 ↔ G-R4 Gi3) — Customer A inter-AS
[ ] Gold↔Garnet (G-R5 Gi3 ↔ Gar-R7 Gi3) — Customer B inter-AS
[ ] Gold as transit: Emerald↔Gold↔Garnet path exists
[ ] BGP path selection between direct and transit paths
[ ] Multi-hop inter-AS (3 AS boundaries) concept
```
