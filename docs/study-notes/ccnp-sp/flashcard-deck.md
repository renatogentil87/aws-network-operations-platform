# Flashcard Deck (running log)

**Agent-maintained file — Renato does not open this.** It's my working memory for running his morning recall sessions and tracking spaced repetition. He challenges himself verbally; I pull/track cards from here. Keep it updated after each session.

**PARKED (not read yet — do NOT surface in warm-ups until the chapter is read):**
- EVPN cards (L5, and any future EVPN) → park until SPCOR Ch 13 is read
- Any card on a topic he hasn't studied yet

Cards accumulate here with last score + date. The morning warm-up prioritizes low/flagged cards (that are fair game), then mixes in others for breadth. Update scores after each session.

Legend: score /10 · ⚠️ = flagged for review (≤7 or unknown) · 🅿️ = parked (topic not read yet)

---

## MPLS Fundamentals

| # | Question | Last score | Last seen |
|---|----------|-----------|-----------|
| M1 | LDP vs SR label significance (locally vs globally significant) + SR's advantage | 10 | 2026-08-18 |
| M2 | Two-label stack in L3VPN — name both labels + which protocol assigns each (LDP=transport, MP-BGP=VPN) | 10 | 2026-08-18 |
| M3 | PHP — what it does, which router, why beneficial (+ implicit-null=3) | 10 | 2026-08-18 |
| M4 | `mpls ldp label allocate global host-routes` — what/why, what still works | 10 | 2026-08-16 |
| M5 | LDP Session Protection — condition to stay up + benefit (targeted LDP session) | 9 | 2026-08-16 |

## L2VPN / VPLS

| # | Question | Last score | Last seen |
|---|----------|-----------|-----------|
| L1 | VPWS vs VPLS + MEF mapping (E-Line / E-LAN / E-Tree) | 10 | 2026-08-18 |
| L2 | Split-horizon in VPLS — what it is + why it forces a full mesh | 9 | 2026-08-17 |
| L3 | BGP VPLS label block — formula Base+(VE-ID − Offset), one advertisement covers all | 10 | 2026-08-18 |
| L4 | H-VPLS tiers (N-PE/U-PE), spoke vs mesh PW, spoke split-horizon exemption | 10 | 2026-08-18 |
| L5 | Three EVPN advantages over VPLS (control-plane MAC learning, active-active MH, less BUM) | 🅿️ parked (read Ch 13 first) | 2026-08-17 |

## Carrier Ethernet / ERPS / CFM-OAM

| # | Question | Last score | Last seen |
|---|----------|-----------|-----------|
| E1 | G.8032 Idle state — how many links blocked (ONE=RPL), which node (RPL Owner), why | 10 | 2026-08-18 |
| E2 | FAILURE sequence — adjacent nodes block + send R-APS(SF); RPL Owner unblocks RPL | 10 | 2026-08-18 |
| E3 | MEP vs MIP (location, active/passive, CCM) | 10 | 2026-08-17 |
| E4 | CFM MD levels (cust 5-7 / prov 3-4 / oper 0-2) + how missing level localizes fault (narrowest broken level) | 8 ⚠️ | 2026-08-18 |
| E5 | OAM — acronym, 3 questions (up/where/**SLA/performance**), L3 tools (ping/traceroute) | 9 ⚠️ | 2026-08-18 |

---

---

## DEEP CARDS (L3 / CCIE-lab depth — for mastered topics: MPLS, L3VPN, BGP, L2VPN)

| # | Question | Last score | Last seen |
|---|----------|-----------|-----------|
| D1 | Egress PE VPNv4 shows in/out 24/nolabel — why nolabel; what appears with a downstream labeled hop (CSC → 3-label); 24 = VPN label from MP-BGP | 7 ⚠️ | 2026-08-18 |
| D2 | Two VPNv4 entries same RT, different RD — compete at VRF import not in RIB; full best-path (IGP metric usual tiebreaker) picks CEF; same RD → RR reflects one to clients → no fast failover | 9 | 2026-08-18 |
| D3 | BGP best-path forensics — best = higher router-id → decided at oldest-path (step 9); confirm via `show ip bgp summary` uptimes; `bgp bestpath compare-routerid` makes deterministic | 10 | 2026-08-18 |
| D4 | RR path hiding — THREE fixes: Add-Path (RFC7911), unique RD per PE, Best-External. (SoO is loop-prevention, NOT this.) All feed BGP PIC for fast failover | 3 ⚠️⚠️ | 2026-08-18 |
| D5 | PW DOWN but LDP up — causes: VC-ID mismatch, AC down, MTU mismatch, encap/PW-type mismatch, broken transport LSP to peer /32 (targeted LDP up ≠ transport LSP up). Lead with `show mpls l2transport vc <id> detail` | 8 | 2026-08-18 |

## Priority review queue (fair-game cards to lead with next warm-up)
1. **TE1** — FRR facility backup: PLR behavior, fast-reroute flag requirement, label stacking (scored 6/10)
2. **D4** — RR path hiding fixes (Add-Path / unique-RD / Best-External) — SoO is a DIFFERENT thing. Big gap.
3. **D1** — CSC / downstream-label case (3-label stack); **D5** — transport-LSP-vs-targeted-LDP distinction
4. **E4** — fault localization = *narrowest broken level*
5. **E5** — 3rd OAM question = **performance / SLA**

*(L5 EVPN PARKED until Ch 13. SR cards PARKED until Ch 15 is read. Surface cards M/L/E mostly 9-10 — rotate for maintenance.)*

---

## MPLS Traffic Engineering (NEW — from Lab 03 + interactive sessions Sep 2026)

| # | Question | Last score | Last seen |
|---|----------|-----------|-----------|
| TE1 | FRR scenario: 2 tunnels (60M each), link has 100M RSVP BW. Tunnel2 DOWN why? If link fails, what happens to Tunnel1 (has fast-reroute)? Does Tunnel2 (no fast-reroute) get facility backup protection? | 6 ⚠️⚠️ | 2026-09-09 |
| TE2 | Autoroute announce: why route shows Tunnel as outgoing intf; does VPN traffic auto-use the tunnel; explicit path fails — what sequence happens (re-signal same path-option first, then fallback, make-before-break) | 9 | 2026-09-09 |
| TE3 | Link protection vs Node protection: backup tunnel destination (NHOP vs NNHOP), who is PLR, where is backup tunnel configured (PLR not headend) | — new, not yet tested | — |
| TE4 | Facility backup vs One-to-One: how label stacking shares one bypass for all primaries; `backup-bw` command makes it facility mode | — new, not yet tested | — |
| TE5 | SRLG: what it is (shared physical risk), how configured (`mpls traffic-eng srlg`), `exclude force` vs `exclude preferred`, how it differs from facility backup | — new, not yet tested | — |
| TE6 | Make-before-break: new path signaled before old torn down; Shared Explicit (SE) style prevents double-booking BW | — new, not yet tested | — |
| TE7 | Auto-bandwidth: measures tunnel interface output (not physical link), sampling interval, adjustment threshold, min/max BW | — new, not yet tested | — |
| TE8 | Setup/Hold priority: 0-7 (0=highest), setup X can preempt hold > X (strictly greater), default both = 7 | — new, not yet tested | — |
| TE9 | CSPF vs SPF: CSPF = constrained (considers BW, affinity, TE metric), uses TE database from Type-10 LSA (OSPF) or IS-IS TLVs | — new, not yet tested | — |

## L3VPN Advanced (NEW — from Lab 02 CCIE+ Challenges Sep 2026)

| # | Question | Last score | Last seen |
|---|----------|-----------|-----------|
| V1 | SoO: what it prevents (routing loop on dual-homed CE), where configured (inbound on PE-CE), where checked (outbound on remote PE toward same CE) | — from lab discussion, not formally tested | — |
| V2 | Sham-link: why needed (OSPF intra > inter-area, backdoor wins), source/dest = VRF loopbacks advertised via BGP (not OSPF), creates intra-area adjacency across MPLS core | — from lab discussion, not formally tested | — |
| V3 | DN-bit: set by PE on OSPF LSA redistributed from BGP, prevents second PE from re-redistributing back into BGP (loop prevention) | — from lab discussion, not formally tested | — |
| V4 | RT-Constraint: rtfilter unicast on BOTH sides (PE + RR), PE advertises wanted RTs, RR filters outbound VPNv4. Without RR-side config = no filtering | — from lab, tested and working | — |
| V5 | as-override: needed when same-ASN CEs at different sites, PE replaces customer AS with SP AS in path, without it CE rejects (own AS = loop prevention) | — from lab discussion, not formally tested | — |
| V6 | BGP PIC: `bgp additional-paths install` = pre-install backup in CEF, prefix-INDEPENDENT convergence (one pointer swap for all prefixes regardless of count) | — from lab discussion, not formally tested | — |
| V7 | Admin distance: eBGP=20, OSPF=110, iBGP=200. With eBGP PE-CE: VPN path preferred over OSPF backdoor. With OSPF PE-CE: backdoor preferred → sham-link needed | — from lab observation, not formally tested | — |
| V8 | LDP-IGP sync: configure under `router ospf` not interface; OSPF advertises max-metric when LDP down; test by removing `mpls ip` on REMOTE side; session protection prevents it from triggering | — from lab observation, not formally tested | — |

## Segment Routing + SRv6 (NEW — from Lab E01 + interactive sessions Sep 2026)

| # | Question | Last score | Last seen |
|---|----------|-----------|-----------|
| SR1 | SR-MPLS PHP troubleshooting: P4 shows `Pop` for PE3's prefix-SID in `show mpls forwarding`. Problem? Why does the label stay the same (17103→17103) across hops but Pop at penultimate? | 8 | 2026-09-16 |
| SR2 | SRv6: locator fc00:0:24::/48 on PE5, VPN route advertised with SID fc00:0:24:40::. What SID type? What does it do? Does remote PE need an SRH? (End.DT4, decap+VRF lookup, no SRH for single SID) | 6 ⚠️ | 2026-09-16 |
| SR3 | Inter-AS Option C: PE5 (Gold) sees VPN route from CE1 (Emerald) with next-hop 1.1.1.1 but `show cef vrf` says "no route." Root cause? Fix? (BGP-LU needed on ASBRs, NOT IGP redistribution) | 7 ⚠️ | 2026-09-16 |
| SR4 | SR vs LDP label bindings: 7-router network, how many label bindings for one prefix? LDP = dozens (per-neighbor, locally significant). SR = 1 (global, SRGB+index, same everywhere). Why SR scales better. | ⚠️ new concept | 2026-09-16 |
| SR5 | BGP path manipulation: 3 inter-AS links, prefer Gold transit over direct ASBR1↔ASBR2. Two methods: LOCAL_PREF on ASBR1 (preferred — local to your AS) or AS-PATH prepend on ASBR2 (requires other SP cooperation). LOCAL_PREF beats AS-PATH in best-path algorithm. | 9 | 2026-09-16 |

## Priority review queue (updated 2026-09-16)
1. **SR2** — SRv6 SID types: locator vs prefix-SID, End.DT4 function, SRH only for multiple SIDs (scored 6/10)
2. **SR3** — Inter-AS Option C: BGP-LU for next-hop resolution, NOT IGP redistribution (scored 7/10)
3. **SR4** — SR vs LDP label count — new concept, needs reinforcement
4. **TE1** — FRR facility backup (scored 6/10)
5. **D4** — RR path hiding fixes (scored 3/10)
6. **D1** — CSC / downstream-label case
