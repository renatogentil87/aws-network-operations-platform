# SR-EX01: SR Foundation + Classic LFA

**Platform:** IOS-XRv 9000
**Topology:** See [`00_SR_topology_reference.md`](./00_SR_topology_reference.md)
**Prerequisite:** None (first exercise)
**Snapshot:** `SR-EX01-foundation`

---

## End Goal

Build two coexisting transport domains and add basic fast-reroute protection to the modern one:

- **LDP domain (R1, R2, R3):** OSPF Area 0 + LDP — a legacy SP core.
- **SR domain (R3, R4, R5, R6):** IS-IS L2 + Segment Routing MPLS — a modern SR-MPLS core.
- **R3 is the boundary:** runs *both* OSPF+LDP and IS-IS+SR.
- **Classic (per-prefix) LFA** enabled on the SR domain, and its protection coverage analyzed.

By the end you should be able to articulate the single most important behavioral difference between LDP and SR: **LDP swaps a locally-significant label at every hop; SR keeps the same global prefix-SID label end-to-end until PHP.**

---

## Topology recap (relevant links only)

```
        LDP Domain (OSPF)                    SR Domain (IS-IS L2)
        =================                    ====================

          R2                                      R6
          │                              10.0.36 │  │ 10.0.56
    10.0.12│                                      │  │
          │                          ┌── R3 ──────┘  R5
          R1 ───────── R3 ───────────┤ (boundary)   /│
             10.0.13   (boundary)    ├── 10.0.34 ─ R4 │ 10.0.45
                                      └── 10.0.35 ──── R5
```

| Link | Subnet | Domain |
|------|--------|--------|
| R1↔R2 | 10.0.12.0/24 | LDP (OSPF) |
| R1↔R3 | 10.0.13.0/24 | LDP (OSPF) |
| R3↔R6 | 10.0.36.0/24 | SR (IS-IS) |
| R3↔R4 | 10.0.34.0/24 | SR (IS-IS) |
| R3↔R5 | 10.0.35.0/24 | SR (IS-IS) |
| R4↔R5 | 10.0.45.0/24 | SR (IS-IS) |
| R5↔R6 | 10.0.56.0/24 | SR (IS-IS) |

> **Note on the LDP domain:** R2 and R3 are **not** directly connected. R2 reaches R3 through R1 (`R2 → R1 → R3`). "R1↔R2↔R3 full reachability" in Task 4 means every loopback is reachable across the OSPF/LDP core, transiting R1.

Interface addressing convention on a `10.0.XY.0/24` link: router **X** takes `.X` isn't used — instead each router takes its own router-number host octet, i.e. on `10.0.13.0/24`, R1 = `10.0.13.1`, R3 = `10.0.13.3`. On `10.0.36.0/24`, R3 = `10.0.36.3`, R6 = `10.0.36.6`. (Host octet = router number.)

---

# Section 1 — LDP Domain Setup

## Task 1 — IP addressing (all routers)

Loopback0 = `172.16.<n>.<n>/32`. Core-link host octet = router number.

### R1
```
interface Loopback0
 ipv4 address 172.16.1.1 255.255.255.255
!
interface GigabitEthernet0/0/0/0
 description R1->R3 (LDP/OSPF)
 ipv4 address 10.0.13.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/3
 description R1->R2 (LDP/OSPF)
 ipv4 address 10.0.12.1 255.255.255.0
 no shutdown
!
```

### R2
```
interface Loopback0
 ipv4 address 172.16.2.2 255.255.255.255
!
interface GigabitEthernet0/0/0/3
 description R2->R1 (LDP/OSPF)
 ipv4 address 10.0.12.2 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/0
 description R2->R4 (boundary, not used in EX01)
 ipv4 address 10.0.24.2 255.255.255.0
 no shutdown
!
```

### R3 (boundary — LDP interfaces here)
```
interface Loopback0
 ipv4 address 172.16.3.3 255.255.255.255
!
interface GigabitEthernet0/0/0/0
 description R3->R1 (LDP/OSPF)
 ipv4 address 10.0.13.3 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/1
 description R3->R6 (SR/IS-IS)
 ipv4 address 10.0.36.3 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/2
 description R3->R4 (SR/IS-IS)
 ipv4 address 10.0.34.3 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/3
 description R3->R5 (SR/IS-IS)
 ipv4 address 10.0.35.3 255.255.255.0
 no shutdown
!
```

### R4
```
interface Loopback0
 ipv4 address 172.16.4.4 255.255.255.255
!
interface GigabitEthernet0/0/0/2
 description R4->R3 (SR/IS-IS)
 ipv4 address 10.0.34.4 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/1
 description R4->R5 (SR/IS-IS)
 ipv4 address 10.0.45.4 255.255.255.0
 no shutdown
!
```

### R5
```
interface Loopback0
 ipv4 address 172.16.5.5 255.255.255.255
!
interface GigabitEthernet0/0/0/3
 description R5->R3 (SR/IS-IS)
 ipv4 address 10.0.35.5 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/1
 description R5->R4 (SR/IS-IS)
 ipv4 address 10.0.45.5 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/2
 description R5->R6 (SR/IS-IS)
 ipv4 address 10.0.56.5 255.255.255.0
 no shutdown
!
```

### R6
```
interface Loopback0
 ipv4 address 172.16.6.6 255.255.255.255
!
interface GigabitEthernet0/0/0/1
 description R6->R3 (SR/IS-IS)
 ipv4 address 10.0.36.6 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/0/2
 description R6->R5 (SR/IS-IS)
 ipv4 address 10.0.56.6 255.255.255.0
 no shutdown
!
```

**Commit** all routers.

**Verify addressing:**
```
show ipv4 interface brief
```
All configured interfaces `Up/Up`; loopbacks show `/32`.

---

## Task 2 — OSPF Area 0 on R1, R2, R3

Core interfaces only. Loopback0 passive (advertised, no adjacency on it). LDP-domain interfaces only — **do not** put R3's SR-facing interfaces (Gi1/Gi2/Gi3) into OSPF.

### R1
```
router ospf 1
 router-id 172.16.1.1
 area 0
  interface Loopback0
   passive enable
  !
  interface GigabitEthernet0/0/0/0
   network point-to-point
  !
  interface GigabitEthernet0/0/0/3
   network point-to-point
  !
 !
!
```

### R2
```
router ospf 1
 router-id 172.16.2.2
 area 0
  interface Loopback0
   passive enable
  !
  interface GigabitEthernet0/0/0/3
   network point-to-point
  !
 !
!
```

### R3 (OSPF only on the R1-facing interface)
```
router ospf 1
 router-id 172.16.3.3
 area 0
  interface Loopback0
   passive enable
  !
  interface GigabitEthernet0/0/0/0
   network point-to-point
  !
 !
!
```

**Verify:**
```
show ospf neighbor
```
- R1 should have **two** FULL neighbors (R2 and R3).
- R2 and R3 should each have **one** FULL neighbor (R1).

```
show route ospf
```
R1 learns 172.16.2.2/32 and 172.16.3.3/32; R2 and R3 learn all three LDP-domain loopbacks (R3's own loopback + R1 + R2).

---

## Task 3 — LDP on R1, R2, R3 core interfaces

Enable MPLS LDP on the OSPF core links (not on loopbacks, not on R3's SR interfaces).

### R1
```
mpls ldp
 router-id 172.16.1.1
 interface GigabitEthernet0/0/0/0
 !
 interface GigabitEthernet0/0/0/3
 !
!
```

### R2
```
mpls ldp
 router-id 172.16.2.2
 interface GigabitEthernet0/0/0/3
 !
!
```

### R3 (LDP only on Gi0 toward R1)
```
mpls ldp
 router-id 172.16.3.3
 interface GigabitEthernet0/0/0/0
 !
!
```

**Verify LDP neighbors:**
```
show mpls ldp neighbor brief
show mpls ldp neighbor
```
- R1 ↔ R2 (Oper), R1 ↔ R3 (Oper). R1 has two LDP peers.
- Each peer session `Oper`, with a TCP connection to the peer's LDP router-id.

**Verify LFIB (label forwarding) populated:**
```
show mpls forwarding
show mpls ldp bindings
```
You should see local + remote label bindings for `172.16.1.1/32`, `172.16.2.2/32`, `172.16.3.3/32`, and outgoing labels installed in the forwarding table.

**Checkpoint:** Every LDP-domain loopback has a remote label from each LDP peer, and `show mpls forwarding` shows a labeled outgoing path (or `Pop` for the penultimate hop).

---

## Task 4 — Verify R1↔R2↔R3 reachability via LDP

Remember R2↔R3 transits R1.

```
! From R2, reach R3's loopback
ping 172.16.3.3 source 172.16.2.2

! From R1, reach both
ping 172.16.2.2 source 172.16.1.1
ping 172.16.3.3 source 172.16.1.1
```

**Labeled traceroute (R2 → R3, transiting R1):**
```
traceroute 172.16.3.3 source 172.16.2.2
```
Expected — each hop shows an MPLS label, and **the label changes at each hop** (LDP is locally significant):
```
 1  10.0.12.1 [MPLS: Label 24001 Exp 0]   <- R1 swaps
 2  10.0.13.3                              <- PHP: R1 popped, R3 receives unlabeled
```
(Exact label values vary; the point is that LDP assigns a *different* label per hop.)

**Section 1 checkpoint:** OSPF FULL across the LDP core, LDP `Oper` sessions, LFIB populated, and labeled forwarding between all three routers. Contrast this label-swap behavior with SR in Task 8.

---

# Section 2 — SR Domain Setup

## Task 5 — IS-IS L2 on R3, R4, R5, R6 (instance `CORE`)

- Level-2-only.
- NET-IDs derived from `172.16.x.x` loopbacks (see reference table).
- `metric-style wide` (mandatory for SR — SR requires wide metrics / extended TLVs).
- `point-to-point` on every IS-IS interface.
- Loopback0 passive.

> NET reminder: `172.16.3.3` → pad to `1720.1600.3003` → NET `49.0001.1720.1600.3003.00`.

### R3 (also keeps its OSPF+LDP from Section 1)
```
router isis CORE
 is-type level-2-only
 net 49.0001.1720.1600.3003.00
 address-family ipv4 unicast
  metric-style wide
 !
 interface Loopback0
  passive
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/1
  point-to-point
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/2
  point-to-point
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/3
  point-to-point
  address-family ipv4 unicast
  !
 !
!
```

### R4
```
router isis CORE
 is-type level-2-only
 net 49.0001.1720.1600.4004.00
 address-family ipv4 unicast
  metric-style wide
 !
 interface Loopback0
  passive
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/2
  point-to-point
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/1
  point-to-point
  address-family ipv4 unicast
  !
 !
!
```

### R5
```
router isis CORE
 is-type level-2-only
 net 49.0001.1720.1600.5005.00
 address-family ipv4 unicast
  metric-style wide
 !
 interface Loopback0
  passive
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/3
  point-to-point
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/1
  point-to-point
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/2
  point-to-point
  address-family ipv4 unicast
  !
 !
!
```

### R6
```
router isis CORE
 is-type level-2-only
 net 49.0001.1720.1600.6006.00
 address-family ipv4 unicast
  metric-style wide
 !
 interface Loopback0
  passive
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/1
  point-to-point
  address-family ipv4 unicast
  !
 !
 interface GigabitEthernet0/0/0/2
  point-to-point
  address-family ipv4 unicast
  !
 !
!
```

**Verify adjacencies:**
```
show isis adjacency
```
Expected L2 adjacencies (all `Up`):
- R3: R4, R5, R6 (3 adjacencies)
- R4: R3, R5 (2)
- R5: R3, R4, R6 (3)
- R6: R3, R5 (2)

```
show isis neighbors
show route isis
```
Every SR-domain router learns 172.16.3.3, .4.4, .5.5, .6.6 via IS-IS.

---

## Task 6 — Enable SR under IS-IS

Add `segment-routing mpls` under the IPv4 address-family, and a `prefix-sid index` on Loopback0. Index (not absolute label) is the portable form; label = SRGB base (16000) + index.

### R3
```
router isis CORE
 address-family ipv4 unicast
  segment-routing mpls
 !
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid index 3
  !
 !
!
```

### R4
```
router isis CORE
 address-family ipv4 unicast
  segment-routing mpls
 !
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid index 4
  !
 !
!
```

### R5
```
router isis CORE
 address-family ipv4 unicast
  segment-routing mpls
 !
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid index 5
  !
 !
!
```

### R6
```
router isis CORE
 address-family ipv4 unicast
  segment-routing mpls
 !
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid index 6
  !
 !
!
```

> **Default SRGB** on IOS-XR is `16000–23999`, so index *N* → label `16000+N`. No explicit `segment-routing global-block` needed for this exercise.

---

## Task 7 — Verify SR label table & forwarding

```
show isis segment-routing label table
```
Expected — prefix-SID labels present across the SR domain:
```
 Label    Prefix/Interface
 16003    172.16.3.3/32
 16004    172.16.4.4/32
 16005    172.16.5.5/32
 16006    172.16.6.6/32
```

```
show mpls forwarding
```
Look for **SR Pfx (idx N)** entries — e.g. on R4:
```
Local  Outgoing   Prefix          Outgoing   Next Hop     ...
Label  Label      or ID           Interface
16005  Pop        SR Pfx (idx 5)  Gi0/0/0/1  10.0.45.5    (R5 is direct -> PHP)
16006  16006      SR Pfx (idx 6)  Gi0/0/0/1  10.0.45.5    (to R6 via R5, label kept)
16003  Pop        SR Pfx (idx 3)  Gi0/0/0/2  10.0.34.3    (R3 direct -> PHP)
```

```
show segment-routing mpls
show isis segment-routing prefix-sid
```

**Confirm no LDP on the SR domain (except R3):**
```
! On R4, R5, R6 — should be empty / not configured
show mpls ldp neighbor
show run mpls ldp

! On R3 — LDP still present, but ONLY on Gi0 (toward R1)
show mpls ldp interface
```
R3's LDP interface list must show **only** `GigabitEthernet0/0/0/0`. If any SR-facing interface (Gi1/2/3) appears under LDP, remove it — the SR domain must be pure SR.

**Checkpoint:** SIDs 16003–16006 present everywhere in the SR domain; `SR Pfx` entries in the forwarding table; LDP confined to R3↔R1.

---

## Task 8 — SR vs LDP label behavior (the key comparison)

### SR: R6 traceroute to R4 — same label until PHP
Path: `R6 → R5 → R4` (R6 has no direct link to R4; R5 is the transit).
```
traceroute 172.16.4.4 source 172.16.6.6
```
Expected — **the same SR label (16004) is imposed and preserved hop by hop** until the penultimate router pops it (PHP):
```
 1  10.0.56.5 [MPLS: Label 16004 Exp 0]   <- R6 pushes 16004
 2  10.0.45.4                              <- R5 is PHP for R4: pops, R4 receives unlabeled
```
The label **16004 identifies R4 globally** — every router in the SR domain agrees on it. No per-hop swap; the transit router (R5) simply forwards based on the same 16004 and pops as PHP.

### LDP: R1 traceroute to R3 — different label every hop
```
traceroute 172.16.3.3 source 172.16.1.1
```
R1↔R3 is a single hop, so for a multi-hop LDP contrast use **R2 → R3** (transits R1):
```
traceroute 172.16.3.3 source 172.16.2.2
```
Expected — LDP labels are **locally significant and change at each hop**:
```
 1  10.0.12.1 [MPLS: Label 24011 Exp 0]   <- R1's locally-chosen label
 2  10.0.13.3                              <- PHP
```

### Takeaway
| | LDP | SR |
|---|-----|-----|
| Label meaning | locally significant (per router) | globally significant (per prefix, network-wide) |
| Label at each hop | **swaps** (different value each hop) | **same value** end-to-end until PHP |
| Label distribution | LDP protocol (extra control plane) | IGP TLVs (no extra protocol) |
| State | per-LSP label bindings everywhere | prefix-SID advertised once by owner |

This is *the* mental model for the rest of the SR track.

---

## Task 9 — Verify adjacency-SIDs

Adjacency-SIDs are dynamically-allocated, link-local labels IS-IS assigns per adjacency. With FRR (Task 10) enabled, IS-IS allocates a **protected** and an **unprotected** adj-SID per neighbor.

```
show isis adjacency detail
```
Expected per adjacency (values are dynamic, typically 24000+):
```
System Id   Interface    SNPA   State  ...  Adjacency SID
R5          Gi0/0/0/1    ...    Up          24012 (protected)   24013 (unprotected)
```

```
show isis segment-routing label table
show mpls forwarding labels 24000 24100
```
Adjacency-SID entries forward out the specific interface toward that one neighbor (`Pop` + push nothing / label imposition per SR-TE steering). Note: *before* enabling FRR you may see only a single (unprotected) adj-SID per neighbor; after Task 10 you should see the protected/unprotected pair.

---

# Section 3 — Classic LFA

## Task 10 — Enable classic (per-prefix) LFA on the SR domain

Classic LFA = precompute a loop-free alternate next-hop for each prefix, install it as a backup in the FIB, and switch to it on local link/adjacency failure (sub-50ms, no reconvergence wait).

Apply on **all four SR-domain routers** (R3, R4, R5, R6), under the IPv4 address-family per interface:

```
router isis CORE
 interface GigabitEthernet0/0/0/1
  address-family ipv4 unicast
   fast-reroute per-prefix
  !
 !
 interface GigabitEthernet0/0/0/2
  address-family ipv4 unicast
   fast-reroute per-prefix
  !
 !
 ! (repeat for every IS-IS core interface on the router)
!
```

> **Classic LFA vs TI-LFA:** `fast-reroute per-prefix` alone = **classic LFA** (needs a directly-connected neighbor that is loop-free by the inequality below; coverage is topology-dependent and often incomplete). Adding `fast-reroute per-prefix ti-lfa` = **TI-LFA** (uses a repair *path* via SR label stack, guarantees 100% coverage). EX01 intentionally uses **classic only** so you can see where it *fails* to protect — TI-LFA is a later exercise.

**Classic LFA loop-free condition (link protection, per-prefix):**
```
Distance(N, D) < Distance(N, S) + Distance(S, D)
```
Neighbor **N** is a valid LFA for source **S** to destination **D** if N's own shortest path to D does not come back through S.

---

## Task 11 — FRR coverage summary

```
show isis fast-reroute summary
```
Expected output shape (numbers depend on where you run it):
```
                     Prefixes    Protected   Unprotected   Protection %
 Critical priority   ...
 High priority       ...
 Medium priority     ...
 Low priority        ...
 Total               N           P           U             (P/N)%
```

**Answer the question — "what percentage of prefixes have LFA backup?"**
- Run it on each of R3/R4/R5/R6 and record the total protection %.
- **R5** (degree-3: neighbors R3, R4, R6) will show the **highest** coverage — it has multiple disjoint neighbors that can serve as LFAs.
- **R4** (degree-2: neighbors R3, R5) and **R6** (degree-2: neighbors R3, R5) will show **lower/partial** coverage — with only two neighbors, one of them is often *not* loop-free for a given destination, so some prefixes stay **Unprotected**.
- Expect **less than 100%** somewhere — that gap is the whole point of this exercise (and the motivation for TI-LFA).

Record actual observed percentages:

| Router | Degree | Total prefixes | Protected | Protection % |
|--------|--------|----------------|-----------|--------------|
| R3 | 3 | ___ | ___ | ___% |
| R4 | 2 | ___ | ___ | ___% |
| R5 | 3 | ___ | ___ | ___% |
| R6 | 2 | ___ | ___ | ___% |

---

## Task 12 — LFA detail for R6's loopback

Run on **R4** (this feeds Task 13, where R4 is the source):
```
show isis fast-reroute 172.16.6.6/32 detail
```

**Question: which neighbor is the LFA for R6's loopback (172.16.6.6/32), and is it loop-free?**

Analysis for **R4 → R6** (assume all metrics = 10):
- R4's primary path to R6: `R4 → R5 → R6` (cost 20), primary next-hop = **R5** (Gi0/0/0/1).
- R4's only other neighbor: **R3**. Is R3 a loop-free alternate?
  - Apply the inequality with S=R4, N=R3, D=R6:
    `Dist(R3,R6) < Dist(R3,R4) + Dist(R4,R6)`
    `10 (R3–R6 direct) < 10 (R3–R4) + 20 (R4–R6) = 30` → **TRUE**.
  - R3 reaches R6 directly (`R3 → R6`, cost 10) **without** traversing R4. So **R3 is a valid, loop-free LFA**.

Expected detail output:
```
172.16.6.6/32
  via 10.0.45.5, GigabitEthernet0/0/0/1, R5   (primary)
    FRR backup via 10.0.34.3, GigabitEthernet0/0/0/2, R3
    P: No  <-- (LFA, not primary)  ... backup is loop-free
```

**Answer:** the LFA for 172.16.6.6/32 on R4 is **R3** (via Gi0/0/0/2 / 10.0.34.3), and **yes, it is loop-free** because R3 has an independent direct path to R6 that does not return through R4.

> If you run the same command on **R6** for a destination like 172.16.4.4/32, you may find **no** LFA (R6's neighbors are R3 and R5; for some destinations neither is loop-free) — that's the partial-coverage story from Task 11.

---

## Task 13 — Failure test: continuous ping R4 → R6, break the primary path

> **Topology correction:** the prompt says "shut R4's Gi2 (direct link to R5)". Per the reference link map, **R4↔R5 is Gi0/0/0/1** and **R4↔R3 is Gi0/0/0/2 (Gi2)**. The link *on R4→R6's primary path* is the **R4↔R5** link = **Gi0/0/0/1**. Shut **Gi0/0/0/1** to break the primary path and exercise the LFA. (Shutting Gi2 would instead cut the R4↔R3 link, which is the *backup*, not the primary.)

### Step 1 — start continuous ping from R4 to R6's loopback
```
ping 172.16.6.6 source 172.16.4.4 count 100000
```
(Or a repeat/rapid ping; keep it running in one session.)

### Step 2 — confirm the pre-failure path & installed backup
```
show route 172.16.6.6/32
show cef 172.16.6.6/32 detail
```
Primary via R5 (Gi0/0/0/1); FIB shows a **backup/repair** next-hop via R3 (Gi0/0/0/2) — installed by classic LFA.

### Step 3 — break the primary link (in a second session)
```
interface GigabitEthernet0/0/0/1
 shutdown
```

### Step 4 — observe
```
show cef 172.16.6.6/32 detail
show isis fast-reroute 172.16.6.6/32 detail
```

**Expected result for this topology:** traffic **recovers**, with **minimal loss (typically 0–2 packets)**.
- The LFA (R3, from Task 12) was **precomputed and preinstalled**, so on link-down the linecard switches to the backup next-hop in the data plane *before* IS-IS reconverges.
- New forwarding path after failure: `R4 → R3 → R6` (R4 pushes 16006, R3 forwards toward R6, PHP at R3).

**"Does traffic recover? How many packets lost?"**
- **Yes** — classic LFA protects this specific prefix because a loop-free alternate (R3) exists.
- **Loss:** expect **0–2 packets** (the in-flight packet(s) during the FIB switchover). Contrast with **no FRR**, where loss would last for the full IS-IS reconvergence (hundreds of ms → several dropped packets).

**"Classic LFA may or may not protect depending on topology" — demonstrate the failure case:**
- Repeat the experiment for a destination/source where classic LFA found **no** backup in Task 11 (an *Unprotected* prefix — often something protected only via a neighbor that loops back). For those, breaking the primary link produces loss for the full reconvergence time.
- This is the concrete motivation for **TI-LFA** (next exercise): guaranteed 100% coverage via a computed repair *path*, not just a single loop-free neighbor.

### Step 5 — restore
```
interface GigabitEthernet0/0/0/1
 no shutdown
```
Stop the ping. Confirm the primary path returns:
```
show route 172.16.6.6/32
show cef 172.16.6.6/32 detail
```

---

# Completion Checklist

## Section 1 — LDP Domain
- [ ] Task 1: All loopbacks (172.16.x.x/32) and core-link IPs (10.0.XY.0/24) configured; `show ipv4 interface brief` all Up/Up.
- [ ] Task 2: OSPF Area 0 up — R1 has 2 FULL neighbors, R2 & R3 have 1 each; loopbacks passive.
- [ ] Task 3: LDP sessions `Oper` (R1↔R2, R1↔R3); LFIB populated (`show mpls forwarding`, `show mpls ldp bindings`).
- [ ] Task 4: R1↔R2↔R3 loopback reachability OK; labeled traceroute shows LDP labels **changing per hop**.

## Section 2 — SR Domain
- [ ] Task 5: IS-IS L2 (instance CORE) adjacencies Up (R3=3, R4=2, R5=3, R6=2); `metric-style wide`; point-to-point.
- [ ] Task 6: `segment-routing mpls` enabled; prefix-SID index R3=3, R4=4, R5=5, R6=6 on Loopback0.
- [ ] Task 7: `show isis segment-routing label table` shows 16003–16006; `show mpls forwarding` shows SR Pfx entries; LDP confined to R3↔R1.
- [ ] Task 8: R6→R4 traceroute shows **same label (16004) until PHP**; R2→R3 LDP traceroute shows **different label per hop**.
- [ ] Task 9: `show isis adjacency detail` shows protected + unprotected adj-SIDs per neighbor.

## Section 3 — Classic LFA
- [ ] Task 10: `fast-reroute per-prefix` (classic LFA) on all IS-IS core interfaces of R3/R4/R5/R6.
- [ ] Task 11: `show isis fast-reroute summary` recorded per router; protection % noted (expect <100% on degree-2 nodes R4/R6).
- [ ] Task 12: LFA for 172.16.6.6/32 on R4 identified = **R3**, confirmed loop-free via the LFA inequality.
- [ ] Task 13: Continuous ping R4→R6, shut R4 **Gi0/0/0/1** (R4↔R5, the primary path); traffic recovers with **0–2 packets lost**; link restored.

## Wrap-up
- [ ] Save configs (`commit` already done per task; optionally `copy running-config`).
- [ ] **Take snapshot: `SR-EX01-foundation`**

---

## Key Takeaways
1. **SR label = global** (same prefix-SID everywhere, kept end-to-end until PHP). **LDP label = local** (swapped every hop). Task 8 proves it.
2. SR needs **no separate label-distribution protocol** — the IGP (IS-IS with `metric-style wide`) carries prefix-SIDs and adj-SIDs in TLVs.
3. **Classic LFA** = single precomputed loop-free *neighbor*, coverage is **topology-dependent** and frequently **partial** (degree-2 nodes suffer). It protects R4→R6 here because R3 is loop-free, but leaves gaps elsewhere.
4. That coverage gap is exactly why **TI-LFA** exists — it computes a guaranteed loop-free repair *path* using an SR label stack. (Next exercise.)
