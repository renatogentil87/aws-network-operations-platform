# CCIE SP Study Context — Full AI Reference

**Who:** Renato (rrdog), Senior TAM at AWS, studying for CCNP SP → CCIE SP.
**Date:** September 2026 (updated Sept 25)
**Platform:** GNS3 on EC2 m8i.24xlarge (384GB RAM, 96 vCPU) running IOS-XRv 9000 + Arista vEOS CEs

---

## STUDY METHOD

### Flashcard Sessions
- 5 cards per session. ONE card at a time. Wait for my answer before showing next.
- Score /10. Correct mistakes. Add context I missed.
- Cards ≤7 flagged ⚠️ for review — bring back in future sessions.
- Only test topics I've studied (see "What I've Studied" below).
- Mix troubleshooting scenarios with concept recall.
- Use my actual lab topology when possible.

### Study Approach (current)
- Currently deep-diving Segment Routing via a training course.
- Lab what I learn each evening — don't wait to finish entire training.
- Don't follow workbooks sequentially — match labs to training topics.
- Manual CLI first (build understanding). Automation later (E14/E22 after E01-E06).

### Study Order
```
NOW:        E01 (IS-IS foundation) → E02 (L3VPN) → E03 (MPLS-TE) → E05 (L2VPN) → E06 (Inter-AS)
After SR:   E04 (SR-MPLS advanced), E12 (SR-TE), E20 (LDP→SR migration), E21 (SRv6)
Then:       E07-E23 in order + E24 (CSC)
Automation: E14 (NETCONF) + E22 (NSO) after all protocol labs done
```

---

## MY LAB TOPOLOGY (3 ISPs, 18 XRv + 9 CEs = 27 nodes)

### Emerald AS 65100 (IS-IS + LDP)

| Hostname | R# | Role | Loopback |
|----------|-----|------|----------|
| E-R1 | R1 | PE | 1.1.1.1 |
| E-R2 | R2 | PE | 2.2.2.2 |
| E-R3 | R3 | P | 3.3.3.3 |
| E-R4 | R4 | P | 4.4.4.4 |
| E-R5 | R5 | P + RR + PCE | 5.5.5.5 |
| E-R6 | R6 | ASBR | 6.6.6.6 |

### Gold AS 65300 (IS-IS + SRv6, transit provider)

| Hostname | R# | Role | Loopback IPv4 | IPv6 Loopback | SRv6 Locator |
|----------|-----|------|----------|--------------|-------------|
| G-R1 | R1 | PE | 21.21.21.21 | fc00::21/128 | fc00:0:21::/64 |
| G-R2 | R2 | PE | 22.22.22.22 | fc00::22/128 | fc00:0:22::/64 |
| G-R3 | R3 | P + RR + PCE | 23.23.23.23 | fc00::23/128 | fc00:0:23::/64 |
| G-R4 | R4 | ASBR | 24.24.24.24 | fc00::24/128 | fc00:0:24::/64 |
| G-R5 | R5 | ASBR | 25.25.25.25 | fc00::25/128 | fc00:0:25::/64 |

### Garnet AS 65200 (IS-IS + SR-MPLS)

| Hostname | R# | Role | Loopback |
|----------|-----|------|----------|
| Gar-R1 | R1 | PE | 11.11.11.11 |
| Gar-R2 | R2 | PE | 12.12.12.12 |
| Gar-R3 | R3 | P | 13.13.13.13 |
| Gar-R4 | R4 | P | 14.14.14.14 |
| Gar-R5 | R5 | P | 15.15.15.15 |
| Gar-R6 | R6 | PCE + RR | 16.16.16.16 |
| Gar-R7 | R7 | ASBR | 17.17.17.17 |

### NIC-to-Interface Mapping (XRv 9000)
NIC0=internal, NIC1=MgmtEth, NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3

### Inter-AS Links
- E-R6 ↔ Gar-R7 (Emerald↔Garnet direct)
- E-R6 ↔ G-R4 (Emerald↔Gold)
- G-R5 ↔ Gar-R7 (Gold↔Garnet)

### RR/PCE Design
| AS | RR + PCE | Loopback | Clients |
|----|----------|----------|---------|
| Emerald | E-R5 | 5.5.5.5 | E-R1, E-R2, E-R6 |
| Gold | G-R3 | 23.23.23.23 | G-R1, G-R2, G-R4, G-R5 |
| Garnet | Gar-R6 | 16.16.16.16 | Gar-R1, Gar-R2, Gar-R7 |

### Customer-to-SP Mapping (CRITICAL — reference this for all VRF/VPN tasks)

| Customer | ASN | CEs | SP | VRF | RT |
|----------|-----|-----|-----|-----|-----|
| Customer A | 65012 | CE1 (E-R1), CE2 (E-R1+E-R2 dual-homed) | Emerald | CUST_A | 65012:100 |
| Customer A | 65012 | CE8 (G-R1+G-R2 dual-homed) | Gold | CUST_A | 65012:100 |
| Customer B | 65013 | CE9 (G-R1) | Gold | CUST_B | 65013:100 |
| Customer B | 65013 | CE4 (Gar-R1) | Garnet | CUST_B | 65013:100 |
| OSPF local | — | CE3 (E-R2) | Emerald | CUST_OSPF | 65100:200 |
| OSPF local | — | CE6 (Gar-R2) | Garnet | CUST_OSPF | 65200:200 |
| Customer C (EVPN) | — | CE7 (G-R2), CE5 (Gar-R1+Gar-R2 dual-homed) | Gold + Garnet | E13 lab | — |

**Key rules:**
- Customer A spans Emerald + Gold ONLY (not Garnet)
- Customer B spans Gold + Garnet ONLY (not Emerald)
- Same RT across SPs for the same customer (enables inter-AS "just works")
- Different RD per SP (65100:100 vs 65300:100) for VPNv4 uniqueness
- CE3/CE6 OSPF customers are local to their SP until E06 Section 7 connects them

### Three Different Transports
- Emerald: IS-IS + LDP
- Gold: IS-IS + SRv6 (IPv6 required on all core interfaces)
- Garnet: IS-IS + SR-MPLS (prefix-SIDs, no LDP)

### Gold IPv6 Addressing
- Loopbacks: fc00::XX/128 (XX = last octet of IPv4)
- Core links: fc00:3:Y::/64 (Y = link number, ::1/::2 per end)
- SRv6 locators: fc00:0:XX::/64

---

## LAB EXERCISES (E01-E24, progressive — each builds on previous)

| Lab | Topic | Status | Depends on |
|-----|-------|--------|------------|
| E01 | IS-IS + LDP (Emerald) + SR-MPLS (Garnet) + SRv6 (Gold) | In progress | — |
| E02 | L3VPN — VRFs, PE-CE eBGP/OSPF, within-AS only | In progress | E01 |
| E03 | MPLS-TE — RSVP tunnels on Emerald | Not started | E01 |
| E04 | SR Advanced — TI-LFA, SR-TE, PCE on Garnet | Wait for SR training | E01 |
| E05 | L2VPN — AToM/VPWS + EVPN-VPWS | Not started | E01 |
| E06 | Inter-AS Options A/B/C + Cross-AS OSPF VPN (CE3↔CE6) | Not started | E02 |
| E07 | OAM + Protection | Not started | E01 |
| E08 | BGP Path Control + RR + PIC | Not started | E02 |
| E09 | QoS DiffServ (XR) | Not started | E01 |
| E10 | mVPN profiles | Not started | E02 |
| E11 | Security (auth, Flowspec, RTBH, RPKI) | Not started | E02 |
| E12 | SR-TE Advanced (PCE, Flex-Algo, ODN) | Wait for SR training | E04 |
| E13 | EVPN Full (all 5 route types, multi-homing) | Not started | E02 |
| E14 | NETCONF/YANG + Telemetry + Python workflows | Not started | E02 |
| E15 | VPLS / H-VPLS | Not started | E01 |
| E16 | 6PE / 6VPE | Not started | E02 |
| E17 | BGP Fundamentals + Peering | Not started | E01 |
| E18 | OSPF Advanced | Not started | E01 |
| E19 | Unified MPLS (BGP-LU) | Not started | E02 |
| E20 | LDP→SR Migration (mapping server, sr-prefer) | Wait for SR training | E01 |
| E21 | SRv6 (locators, SIDs, L3VPN over SRv6) | Wait for SR training | E01 |
| E22 | NSO (L3VPN provisioning, rollback, compliance) | Not started | E02, E14 |
| E23 | Internet Services (VRF internet access) | Not started | E02 |
| E24 | Carrier Supporting Carrier (CSC) — 3-label stack | Not started | E02, E06 |

Labs are continuous — start E01, finish it, continue to E02 on same running topology. Snapshot after each major milestone.

---

## CCIE WORKBOOKS (WB01-WB16, all 6 exam domains)

Questions-only versions in `CCIE Workbooks/EVENG/`. Full solutions in `solutions/` subfolder.

| WB | Topic | Domain | Weight |
|----|-------|--------|--------|
| WB01 | IS-IS Foundation | 1: Core Routing | 25% |
| WB02 | MPLS LDP + Unified MPLS | 1 | |
| WB03 | BGP Advanced | 1 | |
| WB04 | Segment Routing SR-MPLS | 1 | |
| WB05 | SRv6 | 1+2 | |
| WB06 | MPLS-TE | 1 | |
| WB07 | L3VPN (Inter-AS Options A/B/C, PE-CE, SoO) | 2: Architectures | 25% |
| WB08 | L2VPN VPWS & VPLS | 2 | |
| WB09 | EVPN | 2 | |
| WB10 | Multicast & mVPN | 2 | |
| WB11 | QoS DiffServ | 2 | |
| WB12 | 6PE/6VPE | 2 | |
| WB13 | Access Connectivity (Q-in-Q, G.8032, MC-LAG, BNG) | 3: Access | 10% |
| WB14 | High Availability & Convergence | 4: HA | 10% |
| WB15 | Security (LPTS, RPKI, Flowspec, RTBH, MACsec) | 5: Security | 10% |
| WB16 | Automation (NETCONF, gRPC, NSO, Python, ZTP) | 6: Automation | 20% |

---

## WHAT I'VE STUDIED (fair game for flashcards)

### Mastered (scored 8-10)
- MPLS fundamentals (LDP, label switching, PHP, LFIB)
- L3VPN (VRF, RD, RT, MP-BGP VPNv4, PE-CE routing, VRF isolation)
- L2VPN (VPWS, VPLS, H-VPLS, pseudowires)
- MPLS-TE (RSVP tunnels, FRR, autoroute, CSPF, make-before-break)
- BGP (best-path, communities, LOCAL_PREF, AS-PATH, MED, RR design)
- IS-IS (L2-only, metric-style wide, adjacency, LSDB, SPF, pseudonodes)
- Carrier Ethernet (G.8032 ERPS, CFM/OAM, MEP/MIP)
- Inter-AS Options A/B/C (concepts — not yet configured in lab)
- CSC (Carrier Supporting Carrier — concepts, 3-label stack)

### Currently Studying (test me but expect gaps)
- Segment Routing SR-MPLS (prefix-SID, adj-SID, SRGB, protected vs unprotected adj-SID)
- SRv6 (locators /64, SID types: End/End.X/End.DT4/End.DT6, SRH, no MPLS labels)
- LDP→SR migration (mapping server, sr-prefer)
- IS-IS single-topology vs multi-topology (troubleshot TLV 236 vs 237 mismatch in lab)
- IS-IS NET-ID derivation (pad each octet to 3 digits, concatenate, split 4.4.4)
- IOS-XR syntax (commit model, route-policy on eBGP, VRF under BGP, OSPF area-based)
- IOS-XR BGP VPNv4 (address-family under neighbor = activation, no `activate` command)
- VRF isolation (CE cannot reach SP core — by design)
- OSPF PE-CE with redistribution (OSPF→BGP now, BGP→OSPF with filters in E06)
- BGP Color Extended Communities + SR-TE (intent-based steering, ODN, color tags match SR-TE policies)
- EVPN All-Active Multi-Homing + DF Election (Designated Forwarder per ES prevents BUM duplication)
- PCE/PCEP + BGP-LS (controller-based path computation, BGP-LS maps topology, PCEP communicates PCC↔PCE)
- SR-TE policies (stateless core, source-routed label stacks, PCE-initiated vs locally computed)
- RSVP-TE vs SR-TE comparison (RSVP = stateful per-flow hop-by-hop, SR-TE = stateless core source-routed)
- BGP PIC clarified (Add-Path = control plane path diversity, PIC = data plane pre-computed backup, sub-second convergence independent of prefix count)

### Not Yet Studied (DO NOT test)
- EVPN deep (route types 1-5 in detail, IRB symmetric/asymmetric, MAC mobility — know DF election basics now)
- TI-LFA (concept known, not configured)
- Flex-Algo (concept only)
- QoS on IOS-XR
- Multicast / mVPN profiles
- NSO / NETCONF / automation (Phase 2 — after protocol labs)
- 6PE / 6VPE
- BNG / Access Connectivity
- Security (RPKI, Flowspec, RTBH, LPTS)

---

## FLASHCARD DECK (all cards with scores — ~65 cards total)

### MPLS Fundamentals
- **M1:** LDP vs SR label significance (locally vs globally significant) → **10/10**
- **M2:** Two-label stack in L3VPN — transport (LDP) + VPN (MP-BGP) → **10/10**
- **M3:** PHP — what, which router, why (implicit-null=3) → **10/10**
- **M4:** `mpls ldp label allocate global host-routes` → **10/10**
- **M5:** LDP Session Protection → **9/10**

### L2VPN / VPLS
- **L1:** VPWS vs VPLS + MEF (E-Line/E-LAN/E-Tree) → **10/10**
- **L2:** Split-horizon in VPLS → **9/10**
- **L3:** BGP VPLS label block formula → **10/10**
- **L4:** H-VPLS tiers (N-PE/U-PE) → **10/10**

### Carrier Ethernet / OAM
- **E1:** G.8032 Idle state → **10/10**
- **E2:** G.8032 failure sequence → **10/10**
- **E3:** MEP vs MIP → **10/10**
- **E4:** CFM MD levels → **8/10 ⚠️**
- **E5:** OAM 3 questions → **9/10**

### Deep Cards
- **D1:** CSC 3-label stack → **7/10 ⚠️**
- **D2:** Two VPNv4 entries same RT different RD → **9/10**
- **D3:** BGP best-path router-id tiebreaker → **10/10**
- **D4:** RR path hiding — Add-Path, unique RD, Best-External → **3/10 ⚠️⚠️ (reviewed, re-test)**
- **D5:** PW DOWN but LDP up — 5 causes → **8/10**

### MPLS-TE
- **TE1:** FRR scenario → **6/10 ⚠️⚠️**
- **TE2:** Autoroute announce → **9/10**
- **TE3:** Link protection vs Node protection: backup tunnel destination (NHOP vs NNHOP) → not tested
- **TE4:** Facility backup vs One-to-One: label stacking shares one bypass → not tested
- **TE5:** SRLG: shared physical risk, `exclude force` vs `exclude preferred` → not tested
- **TE6:** Make-before-break: SE style prevents double-booking BW → not tested
- **TE7:** Auto-bandwidth: measures tunnel output, sampling interval → not tested
- **TE8:** Setup/Hold priority: 0-7, preemption rules → not tested
- **TE9:** CSPF vs SPF: constrained, uses TE database → not tested

### L3VPN Advanced
- **V1:** SoO — prevents loop on dual-homed CE → not formally tested
- **V2:** Sham-link — OSPF intra > inter-area, backdoor wins → not formally tested
- **V3:** DN-bit — OSPF loop prevention across MPLS core → not formally tested
- **V4:** RT-Constraint — rtfilter unicast on both PE + RR → not formally tested
- **V5:** as-override — same-ASN CEs at different sites → not formally tested
- **V6:** BGP PIC — Add-Path = control plane diversity, PIC = data plane pre-computed backup → not formally tested
- **V7:** Admin distance — eBGP=20, OSPF=110, iBGP=200 → not formally tested
- **V8:** LDP-IGP sync — configure under router ospf → not formally tested

### Segment Routing SR-MPLS
- **SR1:** SR-MPLS PHP — same label across hops, Pop at penultimate → **8/10**
- **SR2:** SRv6 SID types — End.DT4, locator vs prefix-SID, SRH for multiple SIDs only → **6/10 ⚠️ (reviewed)**
- **SR3:** Inter-AS Option C — BGP-LU not IGP redistribution → **7/10 ⚠️ (reviewed)**
- **SR4:** SR vs LDP label count — 1 global vs dozens local → **new ⚠️**
- **SR5:** BGP path manipulation — LOCAL_PREF vs AS-PATH prepend → **9/10**
- **SR6:** prefix-SID config location (Loopback0 only under IS-IS), `segment-routing mpls` at process level enables ALL interfaces, adj-SIDs automatic → **new**
- **SR7:** SR label imposition 3 rules: FEC match + downstream SR-enabled + sr-prefer or no LDP label → **new**
- **SR8:** Protected vs unprotected adj-SID: protected = TI-LFA backup, unprotected = dropped on failure. Both auto-allocated. Use unprotected for strict TE only → **new**
- **SR9:** Mapping server: Garnet(SR) needs prefix-SIDs for Emerald(LDP). Configure on Gar-R6 with virtual indexes. Reverse (LDP→SR) works natively. Temporary bridge during migration → **new**
- **SR10:** LDP→SR migration: (1) enable both, (2) sr-prefer, (3) remove LDP gradually, (4) verify no loss. sr-prefer is the key toggle → **new**

### TI-LFA
- **TL1:** TI-LFA basics: reuses existing LSDB, pre-computes backup via modified SPF (remove failed link/node), minimal segment list, pre-installed in FIB, sub-50ms, zero transit state → **new**
- **TL2:** P-space/Q-space: P=reachable from source without failure, Q=can reach dest without failure. PQ-node exists → 1 label. No PQ-node → 2-3 labels. Minimum labels, NOT one per hop → **new**
- **TL3:** Link vs node protection: link = bypasses link only (node dies = blackhole). Node = bypasses entire node (covers both). Node protection = SP standard. `tiebreaker node-protecting`. Falls back to link protection if no node-protecting path → **new**
- **TL4:** TI-LFA vs RSVP-TE FRR: RSVP = pre-signaled backup tunnel (state every hop). TI-LFA = local computation only (zero signaling, zero transit state, per-prefix). TI-LFA replaces RSVP-TE FRR → **new**
- **TL5:** SRLG: interfaces sharing physical risk get same value (arbitrary number). TI-LFA avoids SRLG members in backup. `exclude force` = mandatory, `exclude preferred` = best-effort. MUST tag ALL interfaces sharing the risk → **new**

### SRv6
- **SV1:** SRv6 fundamentals: pure IPv6 forwarding, no MPLS. Transit routers just do IPv6 lookup. Core MUST have IPv6 addresses → **new**
- **SV2:** SRv6 locator: /64 prefix per router. All SIDs allocated within it. IS-IS advertises. Like prefix-SID but it's an address block producing many SIDs → **new**
- **SV3:** SRv6 SID types: End (node), End.X (link), End.DT4 (IPv4 VRF decap), End.DT6 (IPv6 VRF), End.DX4 (specific CE), End.B6 (binding SID). SID encodes the ACTION — unlike MPLS where label is just a number → **new**
- **SV4:** SRH: IPv6 Routing Header Type 4. Contains Segment List + Segments Left counter. Only for MULTIPLE SIDs. Single SID = plain IPv6, no SRH. Transit routers never read it → **new**
- **SV5:** SRv6 encapsulation: ping = native IPv6 (no encap). VPN 1 SID = outer IPv6 + inner customer. VPN + TE = outer IPv6 + SRH + inner customer → **new**
- **SV6:** IS-IS for SRv6: needs ipv6 AF + single-topology + locator reference. Single/multi-topology MUST match all routers. TLV 236 (single) vs 237 (multi) mismatch = routes don't install → **new**
- **SV7:** SRv6 vs SR-MPLS: SRv6 = 16 bytes/SID, needs IPv6 core, native inter-domain, greenfield/5G. SR-MPLS = 4 bytes/label, IPv4-only ok, needs BGP-LU for inter-domain, brownfield → **new**

### Priority Review Queue (updated 2026-09-26)
1. **D4** — RR path hiding (was 3/10, reviewed — RE-TEST)
2. **SR2** — SRv6 SIDs (was 6/10, reviewed — RE-TEST)
3. **SR3** — Option C / BGP-LU (was 7/10, reviewed — RE-TEST)
4. **SR4** — SR vs LDP label count (new)
5. **TE1** — FRR facility backup (6/10)
6. **D1** — CSC 3-label stack (7/10)
7. **SR6-SR10** — New SR cards, test next session
8. **TL1-TL5** — New TI-LFA cards, test next session
9. **SV1-SV7** — New SRv6 cards, test next session

---

## KEY CONCEPTS LEARNED (reference for discussions)

### IOS-XR Gotchas (vs IOS-XE)
- **eBGP requires route-policy** — no policy = 0 routes (the `!` in show bgp summary)
- **No `activate` command** — `address-family` under neighbor = activation
- **VRF under BGP** — `vrf CUST_A` is its own block, not `address-family ipv4 vrf`
- **OSPF** — no `network` command, interfaces go under `area 0` block
- **IS-IS point-to-point** — just `point-to-point`, not `network point-to-point`
- **Commit model** — changes not active until `commit`
- **show commands** — `show bgp` not `show ip bgp`, `show ospf` not `show ip ospf`
- **Arista vEOS CEs** — need `no switchport` before IP, `zerotouch cancel` before `write memory`

### IS-IS
- NET-ID: pad each octet to 3 digits, concatenate, split into 4.4.4
- Single-topology vs multi-topology: MUST match on all routers. Mismatch = IPv6 routes don't install. Clue: `MT (IPv6 Unicast)` in LSP = multi-topology. TLV 236 (single) vs TLV 237 (multi).
- Pseudonodes (.07, .09 in LSDB) = broadcast mode. Fix with `point-to-point` under IS-IS interface.
- Infinity metric in `show isis route` = path exists in LSDB but SPF can't compute route. Check overload-bit or broken link chain.
- `set-overload-bit on-startup 180` = don't transit through me for 180s after boot.
- IS-IS group (CCIE-ISIS) = template with regex, applied via `apply-group`. Local to each router — not distributed.

### Segment Routing
- SR-MPLS: prefix-SID (global, SRGB+index), adj-SID (local, auto-allocated). Same label at every hop.
- `segment-routing mpls` under IS-IS process = enables SR on all IS-IS interfaces at once.
- prefix-SID: configured only on Loopback0. Adj-SIDs: automatic on every IS-IS interface.
- SR advantage over MPLS: eliminates LDP/RSVP. IGP only. Head-end state only for TE. One label globally.
- Protected vs unprotected adj-SID: protected = backup via TI-LFA if link fails. Unprotected = dropped.

### SRv6
- Pure IPv6 forwarding, NOT MPLS. Packets are IPv6 packets.
- Locator (/64) = address block per router. SIDs allocated within it.
- SID types: End (node), End.X (link), End.DT4 (VRF IPv4 decap), End.DT6 (VRF IPv6), End.B6 (binding SID).
- SRH only needed for multiple SIDs (TE). Single SID = plain IPv6 packet.
- Core interfaces MUST have IPv6. No IPv6 = no SRv6.
- IS-IS must have `address-family ipv6 unicast` + `single-topology` + locator referenced.

### LDP→SR Migration
- SR→LDP: needs mapping server (virtual prefix-SIDs for LDP destinations)
- LDP→SR: works natively
- `sr-prefer`: when both LDP and SR labels exist, prefer SR
- Mapping server is temporary — remove after full migration

### Inter-AS Options
- **Option A:** Back-to-back VRF on ASBRs. MPLS terminated → plain IP → new MPLS. Simple, doesn't scale.
- **Option B:** VPNv4 eBGP between ASBRs. Label swap at boundary. One session carries all VPNs. ASBRs hold all VPN routes.
- **Option C:** BGP-LU between ASBRs (PE loopbacks only) + multihop VPNv4 between RRs. End-to-end labeled path. ASBRs hold ~20 routes. Best scalability.

### CSC (Carrier Supporting Carrier)
- Provider carries customer SP's MPLS transparently. 3-label stack.
- PE-CE link runs eBGP **labeled-unicast** (not regular unicast).
- Inner label = customer SP's VPN label. Provider never reads it.
- Different from Inter-AS: in CSC provider is blind to customer's VPNs.

### VRF Isolation
- CE cannot reach SP core (VRF and global table are completely separate)
- Traffic to unknown destinations in VRF = dropped silently
- Never advertise SP infrastructure into customer VRF

### BGP in VPN Context
- eBGP distance 20 beats iBGP distance 200
- RR reflects: `from` = RR, `next-hop` = originating PE
- Both paths kept — eBGP (local CE) preferred, iBGP (via RR) as backup
- OSPF PE-CE: redistribute OSPF→BGP (always). BGP→OSPF with prefix filter (only when remote sites need reachability — E06 Section 7)
- DN-bit: prevents PE from re-importing redistributed OSPF LSA back into BGP
- RD = route uniqueness (passport number). RT = import/export control (mailing address). Different purposes.
- RD uses SP ASN (per-SP unique). RT uses customer ASN (same across SPs for same customer).
- VRF isolation: CE cannot reach SP core. Traffic to unknown VRF destinations = dropped silently.
- `address-family vpnv4 unicast` must exist at BGP process level before VRF address-families work.

### BGP RR Path Hiding
- RR advertises only best path by default → other PEs don't see backup paths → slow convergence
- Three fixes: Add-Path (RFC 7911, RR sends multiple paths), Best-External (advertise best external to iBGP), unique RDs per PE (different RD = different VPNv4 route = RR reflects both)
- SoO is loop prevention, NOT path hiding fix — different problem
- Add-Path = control plane (more paths visible). BGP PIC = data plane (pre-computed backup in FIB, sub-second switchover regardless of prefix count)

### PCE / PCEP / BGP-LS
- BGP-LS: floods IGP topology (nodes, links, SIDs, TE attributes) into BGP so a controller has full network view
- PCE (Path Computation Element): centralized controller that computes constrained paths using the BGP-LS topology
- PCC (Path Computation Client): the router requesting a path from PCE
- PCEP: protocol between PCC and PCE (TCP 4189)
- PCE-initiated: controller pushes SR-TE policy to router without router requesting it
- PCC-initiated: router requests path from PCE, PCE computes and returns segment list
- IOS-XR: configure local PCE/XTC using internal pce daemon + BGP-LS

### BGP Color + SR-TE (Intent-Based Steering)
- Color extended community: tags a BGP VPN route with an intent (e.g., color 100 = low-latency)
- Headend PE: receives VPN route with color 100 + endpoint → checks for matching SR-TE policy
- ODN (On-Demand Next-hop): auto-creates SR-TE policy when a colored route arrives and no policy exists
- No color = IGP shortest path (no TE). Color = steered into SR-TE policy.
- Color is NOT SRv6-specific — works with both SR-MPLS TE and SRv6 TE

### EVPN Multi-Homing Basics
- Ethernet Segment (ES): the multi-homed link bundle (e.g., CE5 dual-homed to Gar-R1+Gar-R2)
- ES-ID: must be identical on both PEs for the same CE
- DF Election: one PE per ES is Designated Forwarder for BUM traffic → prevents duplication
- All-Active: both PEs forward unicast traffic simultaneously (load sharing). DF only matters for BUM.
- Single-Active: only one PE forwards all traffic. Other is standby.
- Type 1 (Ethernet Auto-Discovery): per-ES for mass withdrawal, per-EVI for aliasing
- Type 4 (ES route): used for DF election between PEs

---

## LINKEDIN ARTICLES WRITTEN
1. **SRv6 on IOS-XR Deep Dive** — locators, SID types, L3VPN over SRv6, SRv6-TE, SR-MPLS vs SRv6
2. **IS-IS Single vs Multi Topology** — TLV 236 vs 237 mismatch troubleshooting (from real lab issue)
3. **Inter-AS Option C** — BGP-LU + multihop VPNv4, full config, packet walkthrough
4. **Carrier Supporting Carrier** — 3-label stack, eBGP labeled-unicast, provider transparency
5. **SP Automation is Mandatory** — NSO vs Ansible, 50 hours vs 5 minutes, transactional deployment
6. **Direct Connect Asymmetric Routing** — DX communities 7224:7100/7300, stateful firewall drops
7. **VPC-to-VPC Troubleshooting** — TGW, SG references don't work across TGW, flow logs
8. **BGP `clear` command danger** — `clear ip bgp *` vs `clear ip bgp * soft in`, state machine
9. **LDP→SR Mapping Server** — how SR reaches LDP destinations during migration
