# SR-EX04: Flex-Algo

**Platform:** IOS-XRv 9000
**Topology:** See `00_SR_topology_reference.md`
**Prerequisite:** SR-EX01 (SR-MPLS base) + SR-EX02 (TI-LFA) complete

---

## End Goal

Stand up **two Flexible Algorithm (Flex-Algo) topologies** on the IS-IS SR domain (R3, R4, R5, R6):

- **Algo 128** — optimizes on the **delay** metric.
- **Algo 129** — uses the **IGP** metric but **excludes** links tagged `EXPENSIVE` (affinity `exclude-any`).

Then prove that traffic steered onto each algorithm's prefix-SID takes a **different path** than default Algo 0 (plain IGP-metric SPF).

---

## Flex-Algo Primer (why this works)

- **Algorithm 0** = standard SR: SPF over the IGP metric. Prefix-SID label = SRGB base + index (16000 + N).
- A **Flexible Algorithm** (128–255, user-defined) is a custom constraint-based SPF. Each router computes its own SPF for that algo using the **flooded FAD** (Flex-Algo Definition): metric-type + affinity constraints.
- The **FAD** need only be defined (and advertised with `advertise-definition`) on **one** router. IS-IS floods it domain-wide; every router that *participates* runs the same constrained SPF.
- A router **participates** in an algo only if it **allocates a prefix-SID for that algo** on its loopback. No per-algo prefix-SID = not participating = pruned from that algo's topology.
- Each algo gets its **own prefix-SID label per router** — a separate label range so forwarding can distinguish "get to R6 via Algo 0" from "get to R6 via Algo 128."
- **TI-LFA is computed per-algo** — the backup path for an Algo 128 prefix is computed inside the Algo 128 topology, not the default one.

**Metric-type options:** `igp` (default), `delay` (min-delay, from performance-measurement), `te` (TE metric).
**Affinity constraints:** `include-all`, `include-any`, `exclude-any` — matched against link `affinity flex-algo <name>` tags mapped to bit positions.

---

## Per-Algo Prefix-SID Index Plan

To keep labels readable we use the pattern `<router><algo-suffix>`:

| Router | Algo 0 index / label | Algo 128 index / label | Algo 129 index / label |
|--------|----------------------|------------------------|------------------------|
| R3 | 3  / 16003 | 3128 / 19128 | 3129 / 19129 |
| R4 | 4  / 16004 | 4128 / 20128 | 4129 / 20129 |
| R5 | 5  / 16005 | 5128 / 21128 | 5129 / 21129 |
| R6 | 6  / 16006 | 6128 / 22128 | 6129 / 22129 |

> Label = SRGB base (16000) + index. e.g. R6 Algo 128 = 16000 + 6128 = **22128**. R6 Algo 0 = **16006**.
> Indexes are arbitrary but must be **globally unique** and identical for a given (router, algo) everywhere.

**Link that will be tagged `EXPENSIVE`:** the **R3↔R6 direct link** = `Gi0/0/0/1` on R3 (subnet 10.0.36.0/24). Excluding it forces Algo 129 traffic to R6 to detour via R4/R5.

---

# Section 1 — Flex-Algo 128: Delay Metric (5 tasks)

## Task 1 — Define Flex-Algo 128 (define on R3, floods everywhere)

The FAD only needs to live on one router. Define it on R3.

```
! === R3 ===
router isis CORE
 flex-algo 128
  metric-type delay
  advertise-definition
 !
!
```

> `advertise-definition` makes R3 the FAD **advertiser**. Without it the definition stays local and other routers won't learn algo 128's constraints. It is fine (and common) to advertise from two routers for redundancy — the router with the lowest FAD priority / highest system-ID wins; identical definitions cause no conflict.

## Task 2 — Enable delay measurement on all SR core interfaces

Algo 128 uses the **min-delay** metric, which is populated by performance-measurement (PM). Enable delay-measurement on every SR-domain core interface on every SR router. Without measured delay, IS-IS advertises no min-delay sub-TLV and the delay SPF falls back / prunes.

```
! === R3 ===  (SR core: Gi1→R6, Gi2→R4, Gi3→R5)
performance-measurement
 interface GigabitEthernet0/0/0/1
  delay-measurement
 !
 interface GigabitEthernet0/0/0/2
  delay-measurement
 !
 interface GigabitEthernet0/0/0/3
  delay-measurement
 !
!

! === R4 ===  (SR core: Gi1→R5, Gi2→R3)
performance-measurement
 interface GigabitEthernet0/0/0/1
  delay-measurement
 !
 interface GigabitEthernet0/0/0/2
  delay-measurement
 !
!

! === R5 ===  (SR core: Gi1→R4, Gi2→R6, Gi3→R3)
performance-measurement
 interface GigabitEthernet0/0/0/1
  delay-measurement
 !
 interface GigabitEthernet0/0/0/2
  delay-measurement
 !
 interface GigabitEthernet0/0/0/3
  delay-measurement
 !
!

! === R6 ===  (SR core: Gi1→R3, Gi2→R5)
performance-measurement
 interface GigabitEthernet0/0/0/1
  delay-measurement
 !
 interface GigabitEthernet0/0/0/2
  delay-measurement
 !
!
```

> **Lab tip:** virtual links (EVE-NG) have ~0 real delay, so the measured min-delay is often identical (a few µs) on every link and Algo 128 will pick the *same* path as Algo 0. To force a visible difference, statically advertise delay per link:
> ```
> performance-measurement
>  interface GigabitEthernet0/0/0/1
>   delay-measurement
>    advertise-delay 5000      ! static min-delay in microseconds
> ```
> Set the R3↔R6 direct link to a **high** static delay so the delay-optimized path avoids it, mirroring Section 2's exclusion but via metric rather than affinity.

## Task 3 — Allocate per-algo prefix-SIDs on all participating routers (R3–R6)

Each router opts into Algo 128 by adding a prefix-SID for algorithm 128 on Loopback0.

```
! === R3 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 128 index 3128
  !
 !
!

! === R4 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 128 index 4128
  !
 !
!

! === R5 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 128 index 5128
  !
 !
!

! === R6 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 128 index 6128
  !
 !
!
```

> Keep the existing Algo 0 `prefix-sid index 3/4/5/6` lines — do **not** remove them. A loopback can carry multiple prefix-SIDs, one per algorithm.

## Task 4 — Verify participation and label allocation

```
! Who participates in algo 128 and what's the FAD?
show isis flex-algo 128
```
Expect all four routers (R3, R4, R5, R6) listed as participating, and the FAD showing `Metric-Type: Delay`, advertised by R3.

```
show isis flex-algo 128 detail
```
Confirms metric-type delay and no affinity constraints.

```
! Per-algo SID labels in the local label table
show isis segment-routing label table
```
Expect separate entries for algo 128 alongside algo 0. On R3 you should see the local algo-128 loopback SID (index 3128 → label **19128**) as well as 16003 (algo 0).

```
! Confirm the routes/labels installed for a remote algo-128 prefix
show isis route 172.16.6.6/32 flex-algo 128
show route 172.16.6.6/32
show cef 172.16.6.6/32
```

## Task 5 — Test: Algo 0 path vs Algo 128 path to R6

Compare the default SR path (label **16006**) against the delay-optimized path (label **22128**) from R3.

```
! Default Algo 0 to R6 (IGP metric SPF)
traceroute sr-mpls 172.16.6.6/32
!   or explicitly by label stack:
traceroute mpls traffic-eng 16006

! Algo 128 (delay) to R6
traceroute mpls flex-algo 128 172.16.6.6/32
!   (equivalently push label 22128)
```

**Expected result:** if per-link delays differ (Task 2 tip), the Algo 128 traceroute avoids the high-delay hop and traverses a different sequence of routers than Algo 0. On IOS-XR you can also confirm the imposed label differs:

```
show cef 172.16.6.6/32 detail            ! algo 0 → outgoing label 16006 region
show isis flex-algo 128
```

> If both traceroutes are identical, the link delays are equal — revisit the static `advertise-delay` values so the R3↔R6 link is the most expensive by delay.

---

# Section 2 — Flex-Algo 129: Exclude Links (4 tasks)

## Task 6 — Define Flex-Algo 129 (igp metric + affinity exclude)

```
! === R3 ===  (advertise from R3 again)
router isis CORE
 flex-algo 129
  metric-type igp
  affinity exclude-any EXPENSIVE
  advertise-definition
 !
!
```

The affinity name `EXPENSIVE` must be mapped to a bit position in the flex-algo affinity map so it can be encoded/flooded. Define the map on **every** router that will tag or evaluate links (define it everywhere to be safe):

```
! === R3, R4, R5, R6 (all SR routers) ===
router isis CORE
 affinity-map EXPENSIVE bit-position 0
!
```

> `affinity exclude-any EXPENSIVE` = prune any link whose flex-algo affinity has the `EXPENSIVE` bit set. The affinity-map ties the human name to a bit position; it must be consistent domain-wide.

## Task 7 — Tag the R3↔R6 link as EXPENSIVE

Per the topology, the R3↔R6 direct link is `Gi0/0/0/1` on R3 (10.0.36.0/24). Tag **both ends** so the constraint is symmetric.

```
! === R3 ===  (Gi0/0/0/1 → R6)
router isis CORE
 interface GigabitEthernet0/0/0/1
  affinity flex-algo EXPENSIVE
 !
!

! === R6 ===  (Gi0/0/0/1 → R3)
router isis CORE
 interface GigabitEthernet0/0/0/1
  affinity flex-algo EXPENSIVE
 !
!
```

> Tagging both ends matters: SPF prunes a link from the algo topology when *either* direction carries the excluded affinity, but tagging symmetrically avoids asymmetric routing surprises and matches how you'd model a real "expensive" circuit.

## Task 8 — Allocate prefix-SIDs for algo 129 on all participating routers

```
! === R3 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 129 index 3129
  !
 !
!

! === R4 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 129 index 4129
  !
 !
!

! === R5 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 129 index 5129
  !
 !
!

! === R6 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 129 index 6129
  !
 !
!
```

## Task 9 — Verify: Algo 129 to R6 avoids the R3↔R6 direct link

R6's Algo 129 label = 16000 + 6129 = **22129**.

```
! Participation + FAD (should show affinity exclude-any EXPENSIVE)
show isis flex-algo 129 detail

! The excluded link should not appear in algo-129 SPF for the path to R6
show isis route 172.16.6.6/32 flex-algo 129

! Trace it
traceroute mpls flex-algo 129 172.16.6.6/32
```

**Expected result:** from R3, Algo 0 (16006) reaches R6 in **one hop** over the direct Gi0/0/0/1 link. Algo 129 (22129) **cannot** use that link, so the path detours:

- **R3 → R5 → R6** (via 10.0.35.0/24 then 10.0.56.0/24), or
- **R3 → R4 → R5 → R6** (via 10.0.34 → 10.0.45 → 10.0.56),

depending on IGP metrics. Confirm the direct R3↔R6 hop is **absent** from the Algo 129 traceroute.

```
! Sanity: prove the link is pruned only for algo 129, still used by algo 0
show isis route 172.16.6.6/32              ! algo 0 → 1 hop via R3-R6
show isis route 172.16.6.6/32 flex-algo 129 ! detours
```

---

# Section 3 — Selective Participation (3 tasks)

## Task 10 — Remove R4 from Algo 128

Withdraw R4 both from participating (remove its algo-128 prefix-SID) and remove the FAD/algo config that lives on R4 if any. Since the FAD is advertised from R3, on R4 you only need to drop the per-algo prefix-SID to stop participating.

```
! === R4 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   no prefix-sid algorithm 128 index 4128
  !
 !
!
```

> If R4 also had a local `flex-algo 128` block (e.g. you defined the FAD there too), remove it as well:
> ```
> router isis CORE
>  no flex-algo 128
> !
> ```
> Leaving the FAD advertised by R3 keeps Algo 128 alive domain-wide; only R4's *participation* is withdrawn.

**Verify R4 dropped out and topology routes around it:**

```
show isis flex-algo 128            ! R4 (1720.1600.4004) NOT listed as participating
show isis route 172.16.6.6/32 flex-algo 128
traceroute mpls flex-algo 128 172.16.6.6/32
```
Expected: the Algo 128 topology treats R4 as a non-participant. Any Algo 128 path that previously transited R4 (e.g. R3→R4→R5→R6) now reroutes around R4 (e.g. R3→R5→R6). A destination reachable *only* via R4 in algo 128 would become unreachable in that algo — confirm R6 is still reachable via the remaining mesh.

## Task 11 — Restore R4 to Algo 128

```
! === R4 ===
router isis CORE
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid algorithm 128 index 4128
  !
 !
!
```

**Verify R4 reappears:**

```
show isis flex-algo 128            ! R4 (1720.1600.4004) participating again
show isis route 172.16.4.4/32 flex-algo 128
traceroute mpls flex-algo 128 172.16.4.4/32
```
Expected: R4 is back in the Algo 128 topology; algo-128 paths that benefit from R4 return to using it.

## Task 12 — Verify TI-LFA is per-algo

TI-LFA backups for an Algo 128 prefix must be computed **inside the Algo 128 topology** (respecting its delay metric / participation), not the default Algo 0 topology.

```
! On R3, inspect fast-reroute for an algo-128 prefix (R6)
show isis fast-reroute 172.16.6.6/32 flex-algo 128 detail
```

Confirm in the output:
- A **backup** next-hop / repair path is present for the algo-128 prefix.
- The repair path uses **algo-128 participating** nodes and the algo-128 metric — it should differ from the Algo 0 backup when delays/participation differ.
- After Task 10 (R4 removed), the algo-128 backup must **not** use R4 as a repair node.

```
! Compare against the default algo backup to show they can differ
show isis fast-reroute 172.16.6.6/32 detail        ! algo 0 backup
show isis fast-reroute 172.16.6.6/32 flex-algo 128 detail
```

> Ensure TI-LFA is enabled per SR-EX02 (`fast-reroute per-prefix` + `fast-reroute per-prefix ti-lfa` under the IS-IS interfaces / address-family). Flex-Algo TI-LFA reuses that config but scopes the computation to each participating algorithm.

---

## Completion Checklist

- [ ] **Task 1** — Flex-Algo 128 FAD defined on R3 (`metric-type delay`, `advertise-definition`)
- [ ] **Task 2** — `delay-measurement` enabled on all SR core interfaces (R3/R4/R5/R6); static `advertise-delay` set if lab links have equal delay
- [ ] **Task 3** — Algo 128 prefix-SIDs allocated on R3(3128)/R4(4128)/R5(5128)/R6(6128)
- [ ] **Task 4** — `show isis flex-algo 128` lists all four routers; label table shows algo-128 SIDs (R3=19128)
- [ ] **Task 5** — traceroute Algo 0 (16006) vs Algo 128 (22128) to R6 shows different paths (given differing delays)
- [ ] **Task 6** — Flex-Algo 129 FAD defined (`metric-type igp`, `affinity exclude-any EXPENSIVE`, `advertise-definition`); `affinity-map EXPENSIVE` on all routers
- [ ] **Task 7** — R3↔R6 link (Gi0/0/0/1) tagged `affinity flex-algo EXPENSIVE` on both ends
- [ ] **Task 8** — Algo 129 prefix-SIDs allocated on R3(3129)/R4(4129)/R5(5129)/R6(6129)
- [ ] **Task 9** — traceroute Algo 129 (22129) to R6 avoids the direct R3↔R6 link (detours via R4/R5)
- [ ] **Task 10** — R4's algo-128 prefix-SID removed; `show isis flex-algo 128` no longer lists R4; topology routes around R4
- [ ] **Task 11** — R4's algo-128 prefix-SID restored; R4 reappears in `show isis flex-algo 128`
- [ ] **Task 12** — `show isis fast-reroute ... flex-algo 128 detail` shows backup computed in the algo-128 topology (differs from algo 0)

---

## Snapshot

Save configuration and take an EVE-NG snapshot:

```
! On each router
commit
end
```

**Snapshot name:** `SR-EX04-flexalgo`

---

## Quick Reference — Commands Introduced

| Command | Purpose |
|---------|---------|
| `flex-algo <128-255>` (under `router isis`) | Enter FAD definition context |
| `metric-type {igp\|delay\|te}` | Metric the algo's SPF optimizes on |
| `affinity {include-all\|include-any\|exclude-any} <name>` | Link affinity constraint for the algo |
| `advertise-definition` | Flood this FAD domain-wide (make router the advertiser) |
| `affinity-map <name> bit-position <n>` | Map affinity name → bit position |
| `affinity flex-algo <name>` (under isis interface) | Tag a link with an affinity |
| `prefix-sid algorithm <algo> index <n>` (under loopback AF) | Participate in an algo + assign its SID |
| `performance-measurement` / `delay-measurement` | Measure/advertise link delay for `metric-type delay` |
| `advertise-delay <microseconds>` | Static min-delay override (lab) |
| `show isis flex-algo <algo> [detail]` | Participation list + FAD |
| `show isis segment-routing label table` | Per-algo SID label allocation |
| `show isis route <pfx> flex-algo <algo>` | Route in a specific algo's topology |
| `traceroute mpls flex-algo <algo> <pfx>` | Data-plane path test for an algo |
| `show isis fast-reroute <pfx> flex-algo <algo> detail` | Per-algo TI-LFA backup |
