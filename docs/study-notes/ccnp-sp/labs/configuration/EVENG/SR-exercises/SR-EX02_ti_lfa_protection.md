# SR-EX02: TI-LFA — Link, Node, and SRLG Protection

**Platform:** IOS-XRv 9000
**Topology:** See [`00_SR_topology_reference.md`](./00_SR_topology_reference.md)
**Prerequisite:** SR-EX01 complete (SR-MPLS base: IS-IS L2, SRGB, prefix-SIDs, LDP↔SR boundary on R3)

**End Goal:** TI-LFA (Topology-Independent Loop-Free Alternate) deployed across the SR domain with **node protection as the default tiebreaker**, **SRLG protection** for the shared-duct links, and **sub-50ms failover verified** by continuous ping during link/node failure.

---

## Why TI-LFA (vs classic LFA)

| | Classic LFA / rLFA | TI-LFA |
|---|---|---|
| Coverage | Partial — depends on topology having a loop-free neighbor | ~100% (topology-independent) |
| Repair path | Must be a single loop-free next-hop | Any post-convergence path, encoded as a **repair segment list** (labels) |
| Post-convergence | Backup may differ from the eventual converged path (micro-loops) | Backup **equals** the post-convergence path (loop-free by construction) |
| Node protection | Best-effort | Explicit tiebreaker |
| SRLG protection | Not native | Explicit `srlg-disjoint` tiebreaker |

TI-LFA leverages the SR label stack to steer repair traffic along the exact post-convergence path, so it does not depend on the physical topology providing a "natural" LFA. This is why coverage jumps and why the repair is loop-free even before the network reconverges.

### SR Domain paths to R6 (172.16.6.6) — reference for this exercise

```
        Gi1                 Gi2 (R6)
   R3 ────────── R6     R5 ────────── R6
   │  \                 │
   │Gi2\Gi3             │Gi1
   R4   R5              R4
   └─Gi1─┘  (R4↔R5)

Primary R4→R6:  R4 → R5 → R6        (via Gi1 to R5, then R5 Gi2 to R6)
Backup  R4→R6:  R4 → R3 → R6        (via Gi2 to R3, then R3 Gi1 to R6) — link/node protecting

Primary R3→R6:  R3 → R6            (direct, Gi1)
For R3→R6 via R5 test: force path R3 → R5 → R6, protect against R5 node loss
```

> **SRLG note:** `R3↔R5` (R3 Gi3 ↔ R5 Gi3) and `R4↔R5` (R4 Gi1 ↔ R5 Gi1) are declared to share the **same fiber duct** (SRLG 100). A backup that avoids R3↔R5 must therefore also avoid R4↔R5.

---

## Section 1 — TI-LFA Link Protection (Tasks 1–4)

### Task 1 — Enable TI-LFA on all SR-domain routers (R3, R4, R5, R6)

Apply under the IS-IS IPv4 unicast address-family. TI-LFA is enabled **per-interface** in IOS-XR, so apply it on each SR-domain interface (or use the address-family default and then per-interface `fast-reroute` as needed). The standard approach is per-interface under the interface's address-family.

**R3:**
```
router isis 1
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
 interface GigabitEthernet0/0/0/2
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
 interface GigabitEthernet0/0/0/3
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
!
```

**R4:**
```
router isis 1
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
 interface GigabitEthernet0/0/0/2
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
!
```

**R5:**
```
router isis 1
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
 interface GigabitEthernet0/0/0/2
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
 interface GigabitEthernet0/0/0/3
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
!
```

**R6:**
```
router isis 1
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
 interface GigabitEthernet0/0/0/2
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
  !
 !
!
```

> **Interface reference (from topology link map):**
> - R3 Gi1→R6, Gi2→R4, Gi3→R5
> - R4 Gi1→R5, Gi2→R3
> - R5 Gi1→R4, Gi2→R6, Gi3→R3
> - R6 Gi1→R3, Gi2→R5
>
> `commit` after configuration on each router.

---

### Task 2 — Verify backup paths and repair segment list

On **R4** (the router we will fail-test):

```
show isis fast-reroute summary
```

**Expected:** near-100% prefix protection in the SR domain — noticeably higher than classic LFA from EX01. Look at the "Protection coverage" line; TI-LFA should show close to 100% (Total protected ≈ Total prefixes).

```
show isis fast-reroute 172.16.6.6/32 detail
```

**Expected:** primary next-hop toward R5, plus a **backup** next-hop toward R3 with a **repair path (segment list)**. Key fields to confirm:
- `Backup path:` present
- `P node` / `Q node` computed (the TI-LFA PQ nodes)
- `Repair path:` with a label stack (prefix-SID / adj-SID segments encoding the post-convergence path, e.g. push `16003` toward R3 then `16006` for R6, or an adj-SID)
- Protection type shown as at least link-protecting

```
show isis fast-reroute 172.16.6.6/32 detail
--- example (abbreviated) ---
  L2 172.16.6.6/32 [20/115]
     via 10.0.45.5, GigabitEthernet0/0/0/1, R5, SRGB Base: 16000, Weight: 0
       Backup path: TI-LFA (link), via 10.0.34.3, GigabitEthernet0/0/0/2, R3
         P node: R3 [172.16.3.3], Label: 16003
         Q node: R6 [172.16.6.6], Label: 16006
         Prefix label: 16006
         Backup-src: R6
```

---

### Task 3 — Confirm backup pre-installed in FIB (CEF)

```
show cef 172.16.6.6/32 detail
```

**Expected:** the FIB entry carries **both** the primary next-hop and a **repair/backup** next-hop with **repair labels** already programmed — so the hardware switches over on link-down without waiting for control-plane reconvergence.

```
show cef 172.16.6.6/32 detail
--- example (abbreviated) ---
172.16.6.6/32, version ..., internal 0x1000001 ...
  local adjacency 10.0.45.5
  Prefix Len 32, traffic index 0, ...
  via 10.0.45.5/32, GigabitEthernet0/0/0/1, 0 dependencies, primary
     path-idx 0, next hop 10.0.45.5
     labels imposed {16006}
  via 10.0.34.3/32, GigabitEthernet0/0/0/2, backup (remote)  <-- repair
     path-idx 1, next hop 10.0.34.3
     labels imposed {16003 16006}   <-- repair segment list
```

Confirm the backup path's `labels imposed` matches the repair segment list from Task 2.

---

### Task 4 — Test link failure (continuous ping R4→R6)

**Setup:** on R4, start a continuous, high-rate ping to R6 loopback so packet loss maps to failover time.

```
R4# ping 172.16.6.6 count 100000 size 100 repeat 100000
!  (or: ping 172.16.6.6 count 500  — IOS-XR: use a long count)
```

Better for measuring loss precisely (rapid packets):
```
R4# ping 172.16.6.6 count 1000 timeout 0 interval ... 
```

**Trigger:** shut the R4→R5 link (R4 Gi1):
```
R4(config)# interface GigabitEthernet0/0/0/1
R4(config-if)# shutdown
R4(config-if)# commit
```

**Expected:** **0–1 packets lost** — sub-50ms failover. Traffic instantly follows the pre-installed repair path R4→R3→R6 (labels `{16003 16006}`) while IS-IS reconverges in the background.

**Compare with EX01 classic LFA:** classic LFA (if it even had a valid alternate for this prefix) typically showed higher loss or no protection at all for prefixes lacking a loop-free neighbor. Record both numbers:

| Metric | Classic LFA (EX01) | TI-LFA (EX02) |
|---|---|---|
| Prefix protected? | (partial) | yes |
| Packets lost on R4 Gi1 shut | ___ | 0–1 |
| Failover time | > 50ms / N/A | < 50ms |

**Restore:**
```
R4(config)# interface GigabitEthernet0/0/0/1
R4(config-if)# no shutdown
R4(config-if)# commit
```

---

## Section 2 — TI-LFA Node Protection (Tasks 5–8)

### Task 5 — Set node protection as the preferred tiebreaker

TI-LFA can compute several valid backups; **tiebreakers** (lower index = higher preference) choose which one to install. Configure the SP-standard preference: prefer **node-protecting**, then **SRLG-disjoint**, then any (default). Apply under each protected interface's address-family (shown for R4; apply the same on R3, R5, R6 interfaces).

**R4 (representative — repeat per interface / per router):**
```
router isis 1
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
   fast-reroute per-prefix tiebreaker node-protecting index 100
   fast-reroute per-prefix tiebreaker srlg-disjoint index 200
  !
 !
!
```

> **Tiebreaker semantics (IOS-XR):**
> - Lower `index` = evaluated first / higher priority.
> - `node-protecting index 100` → prefer a backup that bypasses the whole next-hop node.
> - `srlg-disjoint index 200` → next, prefer a backup avoiding SRLG members.
> - The **"default index 300"** in the exercise refers to the implicit lowest-priority fallback (the primary/base LFA computation) — any valid TI-LFA backup is accepted if no node-protecting or SRLG-disjoint one exists. IOS-XR uses index 256 as the internal default weight for the base rule; using `index 300` conceptually documents "last resort." If your image rejects a literal `default` keyword, omit it — the base TI-LFA rule already acts as the fallback. Document intended order as: **node(100) → srlg(200) → default(300 / base).**

`commit` on each router.

---

### Task 6 — Verify node-protecting backup

```
show isis fast-reroute 172.16.6.6/32 detail
```

**Expected:** the backup is now flagged **node-protecting** (not just link). For R4's primary next-hop R5, a node-protecting backup must bypass **R5 entirely** — i.e., R4→R3→R6, which does not traverse R5 at all.

```
--- example (abbreviated) ---
     via 10.0.45.5, GigabitEthernet0/0/0/1, R5, ...
       Backup path: TI-LFA (node-protecting), via 10.0.34.3, Gi0/0/0/2, R3
         P node: R3, Label 16003
         Q node: R6, Label 16006
         Node protected: R5 (172.16.5.5)   <-- bypasses the entire node
```

Confirm the report explicitly states node protection and names R5 as the protected/bypassed node.

---

### Task 7 — Test node failure (continuous ping R3→R6 via R5)

**Goal:** demonstrate that node protection reroutes around a *failed node*, not just a failed link.

**Setup — force R3's path to R6 through R5** so R5 is the protected next-hop node. Options:
- Temporarily raise the metric of R3 Gi1 (R3↔R6 direct link) so the best path R3→R6 becomes R3→R5→R6, **or**
- Use a TI-LFA test where R5 is the primary next-hop node for a target reachable behind it.

```
R3(config)# router isis 1
R3(config-isis)# interface GigabitEthernet0/0/0/1
R3(config-isis-if)# address-family ipv4 unicast
R3(config-isis-if-af)# metric 1000
R3(config-isis-if-af)# commit
```
Verify primary path R3→R6 is now `R3 → R5 → R6`:
```
show isis route 172.16.6.6/32
show route 172.16.6.6/32
```
Confirm the node-protecting backup on R3 bypasses R5 (e.g. R3→R4→...→R6 or R3→R6 direct if metric allows):
```
show isis fast-reroute 172.16.6.6/32 detail
```

**Start continuous ping R3→R6:**
```
R3# ping 172.16.6.6 count 100000 size 100
```

**Trigger node failure — shut ALL interfaces on R5:**
```
R5(config)# interface GigabitEthernet0/0/0/1
R5(config-if)# shutdown
R5(config-if)# interface GigabitEthernet0/0/0/2
R5(config-if)# shutdown
R5(config-if)# interface GigabitEthernet0/0/0/3
R5(config-if)# shutdown
R5(config-if)# commit
```

**Expected:**
- **With node protection:** traffic reroutes **around R5 entirely** → 0–1 packets lost. The pre-installed repair path never points at R5.
- **With link protection only:** a link-only backup might still attempt to reach/transit R5 (only protecting the specific R3–R5 link, not R5 as a node), causing extended loss until IS-IS reconverges.

**Restore:**
```
R5(config)# interface GigabitEthernet0/0/0/1
R5(config-if)# no shutdown
R5(config-if)# interface GigabitEthernet0/0/0/2
R5(config-if)# no shutdown
R5(config-if)# interface GigabitEthernet0/0/0/3
R5(config-if)# no shutdown
R5(config-if)# commit
!
R3(config)# router isis 1
R3(config-isis)# interface GigabitEthernet0/0/0/1
R3(config-isis-if)# address-family ipv4 unicast
R3(config-isis-if-af)# no metric 1000
R3(config-isis-if-af)# commit
```

---

### Task 8 — Compare link-protecting vs node-protecting repair segment lists

Capture and compare `show cef 172.16.6.6/32 detail` for the two cases:

```
show cef 172.16.6.6/32 detail
```

| Case | Backup next-hop | Repair segment list (labels imposed) | Bypasses |
|---|---|---|---|
| Link-protecting (Task 3) | R3 (10.0.34.3) | `{16003, 16006}` | R4–R5 link only |
| Node-protecting (Task 6) | R3 (10.0.34.3) | `{16003, 16006}` — or a stack whose Q-node is beyond R5 | R5 node entirely |

**Key learning:** the **P/Q node computation differs**. For node protection the P-node/Q-node pair is chosen so the repair path provably does **not** traverse the protected node R5, which can change the label stack (different Q-node, additional adj-SID). Note any difference in the repair label stack between the two captures — that difference *is* the node vs link protection.

---

## Section 3 — SRLG Protection (Tasks 9–12)

### Task 9 — Define SRLG 100 on the shared-duct links

**Shared fiber duct:** `R3↔R5` (R3 Gi3 ↔ R5 Gi3) and `R4↔R5` (R4 Gi1 ↔ R5 Gi1). Assign **SRLG value 100** on **both ends of both links** (all four interfaces).

IOS-XR SRLG is configured in a global `srlg` block and referenced per interface:

**R3 (Gi3 → R5):**
```
srlg
 interface GigabitEthernet0/0/0/3
  name DUCT-A
  value 100
 !
 name DUCT-A
  value 100
!
router isis 1
 interface GigabitEthernet0/0/0/3
  address-family ipv4 unicast
  !
 !
!
```

> Simpler/portable form used in most XR images:
```
srlg
 interface GigabitEthernet0/0/0/3
  value 100
!
```

**R5 (Gi3 → R3):**
```
srlg
 interface GigabitEthernet0/0/0/3
  value 100
!
```

**R4 (Gi1 → R5):**
```
srlg
 interface GigabitEthernet0/0/0/1
  value 100
!
```

**R5 (Gi1 → R4):**
```
srlg
 interface GigabitEthernet0/0/0/1
  value 100
!
```

`commit` on each. Verify:
```
show srlg
show isis interface GigabitEthernet0/0/0/3   (confirm SRLG advertised in IS-IS)
```

**Expected:** IS-IS advertises SRLG membership (value 100) so all SR-domain routers know R3↔R5 and R4↔R5 belong to the same risk group.

---

### Task 10 — Enable/verify SRLG-aware TI-LFA

No new command needed — the `fast-reroute per-prefix tiebreaker srlg-disjoint index 200` from **Task 5** already enables SRLG-aware backup selection. Confirm it is present on the protected interfaces:

```
show run router isis 1 | include tiebreaker
```

Verify backup avoids SRLG members:
```
show isis fast-reroute 172.16.6.6/32 detail
```

**Expected:** the detail output notes the backup is **SRLG-disjoint** (or lists the SRLG it excluded). The chosen backup must not traverse any link in SRLG 100.

---

### Task 11 — Test SRLG protection

**Trigger:** shut **R3 Gi3** (R3→R5 link, a member of SRLG 100):
```
R3(config)# interface GigabitEthernet0/0/0/3
R3(config-if)# shutdown
R3(config-if)# commit
```

**Expected behavior:** the SRLG-disjoint backup for prefixes previously using R3↔R5 must **NOT** fall back onto `R4↔R5` (also SRLG 100 — same duct, would fail simultaneously in a real fiber cut). Instead it selects an alternative avoiding **both** SRLG-100 members — e.g. via R3→R6 direct (Gi1) or R3→R4→(non-SRLG path)→R6.

Verify on R3 (and any router whose backup transited R3↔R5):
```
show isis fast-reroute detail | begin 172.16
show isis fast-reroute 172.16.6.6/32 detail
show cef 172.16.6.6/32 detail
```

Confirm the repair path's outgoing interface/segment list contains **no** SRLG-100 link.

**Restore:**
```
R3(config)# interface GigabitEthernet0/0/0/3
R3(config-if)# no shutdown
R3(config-if)# commit
```

---

### Task 12 — Verify SRLG-disjoint backup

```
show isis fast-reroute 172.16.6.6/32 detail
```

**Expected:** backup path explicitly reported as **SRLG-disjoint**; none of the repair segments cross SRLG 100. Example marker:
```
       Backup path: TI-LFA (node-protecting, SRLG-disjoint), via ...
         SRLG disjoint: yes (excluded SRLG 100)
```

Record which alternative path was selected and confirm it shares no risk group with the primary.

---

## Section 4 — TI-LFA Preference Verification (Tasks 13–15)

### Task 13 — Flip preference to favor link protection

Change tiebreaker indexes so the **default/base (link)** rule outranks node-protecting, then confirm the installed backup changes from node-protecting to link-protecting. Apply on R4 (representative interface):

```
router isis 1
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix tiebreaker node-protecting index 100
   ! set the base/link rule to a LOWER (higher-priority) index than node
   ! (documented as: default index 50, node index 100)
  !
 !
!
```

> Because IOS-XR does not expose a literal `default` tiebreaker keyword on all images, demonstrate the flip by **lowering node-protecting's priority below the base rule**. The practical way: either remove `srlg-disjoint`/raise node index, or set node-protecting to a higher index than the base. Conceptually: **default index 50 (wins) > node-protecting index 100.**

Verify the change:
```
show isis fast-reroute 172.16.6.6/32 detail
```

**Expected:** backup now reported as **link-protecting** (repair only bypasses the R4–R5 link, and may still transit R5), no longer node-protecting. This proves tiebreaker index ordering drives backup selection.

---

### Task 14 — Restore standard SP preference

Return to: **node-protecting 100 → srlg-disjoint 200 → default 300 (base)**.

```
router isis 1
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix
   fast-reroute per-prefix ti-lfa
   fast-reroute per-prefix tiebreaker node-protecting index 100
   fast-reroute per-prefix tiebreaker srlg-disjoint index 200
  !
 !
!
```
Repeat on all protected interfaces / routers. `commit`.

Verify node protection is back:
```
show isis fast-reroute 172.16.6.6/32 detail   (should show node-protecting again)
```

---

### Task 15 — Confirm full coverage

```
show isis fast-reroute summary
```

**Expected:** **100% (or near-100%) protection coverage** across the SR domain — every SR-domain prefix has a TI-LFA backup. Note the "Protected / Total" counts and confirm they match.

```
--- example (abbreviated) ---
Prefixes reachable in L2:
  Total num of prefixes ..............: NN
  Protected (TI-LFA) .................: NN   (100.00%)
  Node protected .....................: NN
  SRLG protected .....................: NN
```

---

## Completion Checklist

- [ ] **Task 1** — `fast-reroute per-prefix ti-lfa` enabled on all SR-domain interfaces of R3, R4, R5, R6
- [ ] **Task 2** — `show isis fast-reroute summary` coverage higher than classic LFA; `172.16.6.6/32 detail` shows repair segment list
- [ ] **Task 3** — `show cef 172.16.6.6/32 detail` shows primary + backup with repair labels pre-installed in FIB
- [ ] **Task 4** — R4→R6 ping during R4 Gi1 shut: 0–1 packets lost (sub-50ms); compared to EX01 classic LFA
- [ ] **Task 5** — Tiebreakers set: node-protecting 100, srlg-disjoint 200, default/base 300
- [ ] **Task 6** — `172.16.6.6/32 detail` reports node-protecting; backup bypasses R5 entirely
- [ ] **Task 7** — R3→R6-via-R5 ping during full R5 shut: reroutes around R5 (node protection proven)
- [ ] **Task 8** — Compared link vs node repair segment lists (P/Q node difference documented)
- [ ] **Task 9** — SRLG 100 assigned on R3 Gi3, R5 Gi3, R4 Gi1, R5 Gi1 (both ends of both links)
- [ ] **Task 10** — `srlg-disjoint index 200` verified; backup avoids SRLG members
- [ ] **Task 11** — R3 Gi3 (SRLG 100) shut: backup does NOT use R4↔R5 (SRLG 100)
- [ ] **Task 12** — `show isis fast-reroute detail` confirms SRLG-disjoint backup
- [ ] **Task 13** — Preference flipped (default 50 > node 100): backup changes to link-protecting
- [ ] **Task 14** — Restored SP preference (node 100, srlg 200, default 300)
- [ ] **Task 15** — `show isis fast-reroute summary` confirms 100% coverage in SR domain

**Snapshot:** `SR-EX02-tilfa`

---

## Notes & Gotchas

- **Per-interface, not global:** In IOS-XR, `fast-reroute` and TI-LFA are configured under each interface's `address-family ipv4 unicast` within `router isis`, not once globally. Enable it on every SR-domain interface you want protected.
- **`default` tiebreaker keyword:** Some IOS-XRv 9000 images do not accept a literal `default` tiebreaker. The base TI-LFA computation *is* the fallback (lowest priority). Where the exercise says "default index 300," document the intended fallback ordering; only `node-protecting` and `srlg-disjoint` are explicit tiebreaker keywords.
- **Measuring sub-50ms:** Packet loss is a proxy for failover time. Use a high packet rate / short interval so 1 lost packet ≈ tens of ms. IOS-XR `ping` interval control is limited; for precise numbers use an external traffic generator or `ping ... count <large>` and infer from loss.
- **SRLG realism:** SRLG only protects if the alternate genuinely avoids the shared risk group. In this topology, after shutting R3↔R5 the valid SRLG-disjoint path to R6 typically uses R3→R6 direct (Gi1) or a path through R4 that reaches R6 without the R4↔R5 link.
- **Node protection needs a bypass:** Node protection can only be installed if a backup exists that avoids the entire next-hop node. Confirm the topology mesh (R3↔R4, R3↔R6, R5↔R6) provides one; otherwise XR falls back to link protection for that prefix.
- **LDP↔SR boundary (R3):** TI-LFA here is scoped to the IS-IS/SR domain. Prefixes learned from the OSPF/LDP side are protected only to the extent R3 has an SR-domain backup toward them.
