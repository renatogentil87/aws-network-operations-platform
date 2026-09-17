# CCIE SP Workbook 06 — MPLS Traffic Engineering (RSVP-TE)

**Exam Domain:** Domain 1 — Core Routing (25%)
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv 9000 7.11.1) — see `00_EVENG_Topology.md`
**Focus:** Emerald **AS 65100** — IS-IS L2 + LDP + **RSVP-TE**
**Prerequisites:** IS-IS L2 backbone with **wide metrics** and /32 loopbacks (Workbook 01), LDP for baseline label transport (Workbook 03).

> **Note:** This workbook is classic **RSVP-TE** — stateful, per-hop signaled LSPs with soft-state Path/Resv refresh. It contrasts with Workbook 09 (SR-TE), which is stateless and needs no RSVP. RSVP-TE remains heavily weighted in CCIE-SP Core Routing because it teaches CSPF, bandwidth accounting, FRR, and DS-TE — the conceptual foundation SR-TE builds on. All syntax is **IOS-XR**.

---

## Topology (Emerald AS 65100)

```
                       PCE1 (6.6.6.6)
                         │ 10.1.1.0/24
                         │
   ASBR1 (5.5.5.5) ──────P2 (4.4.4.4)
        10.1.2.0/24      │ 10.1.3.0/24
                         │
                       P1 (3.3.3.3)
              10.1.4.0/24 │ │ 10.1.5.0/24
                 ┌────────┘ └────────┐
              PE1 (1.1.1.1)        PE2 (2.2.2.2)
                 └──────────────────┘
                     10.1.6.0/24
```

| Link | Subnet | A-end / Z-end |
|------|--------|---------------|
| PCE1 ↔ P2   | 10.1.1.0/24 | PCE1=.6 / P2=.4 |
| P2 ↔ ASBR1  | 10.1.2.0/24 | P2=.4 / ASBR1=.5 |
| P2 ↔ P1     | 10.1.3.0/24 | P2=.4 / P1=.3 |
| P1 ↔ PE1    | 10.1.4.0/24 | P1=.3 / PE1=.1 |
| P1 ↔ PE2    | 10.1.5.0/24 | P1=.3 / PE2=.2 |
| PE1 ↔ PE2   | 10.1.6.0/24 | PE1=.1 / PE2=.2 |

**Path note:** The IGP shortest path PE1→PE2 is the direct link `10.1.6.0/24` (1 hop). TE tunnels in this workbook are engineered *away* from that path — via **PE1→P1→PE2** — so you can observe TE overriding IGP.

---

## Section 1 — RSVP-TE Basics

### Task 1.1 — Enable MPLS-TE and RSVP on all Emerald core interfaces

Enable the RSVP-TE control plane globally and per-interface, extend IS-IS to flood TE link attributes, and bring RSVP up on every core link.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.2 — Configure a TE tunnel PE1→PE2 via explicit path (PE1→P1→PE2)

On PE1 build `tunnel-te1` to PE2 (2.2.2.2) forced onto the **non-shortest** path PE1→P1→PE2 using an explicit-path.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.3 — Autoroute announce

Make PE1's IGP/CEF use `tunnel-te1` to reach PE2 and prefixes behind it, without static routes.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.4 — Verify tunnel UP and traffic forwarded

Confirm the LSP is UP end-to-end and data-plane traffic is actually label-switched over PE1→P1→PE2.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 1.5 — TE metric vs IGP metric

Configure the tunnel to compute its dynamic path using the **TE metric** instead of the IGP metric, and set per-link TE metrics so the two produce different paths.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 2 — FRR Protection

### Task 2.1 — Link protection (facility backup bypass tunnel)

Protect the PE1→P1 link (primary tunnel's first hop) with a **NHOP bypass** tunnel on PE1 that reroutes around the protected link to P1.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 2.2 — Node protection (NNHOP bypass)

Protect against **P1 node** failure with a bypass on PE1 that skips P1 entirely and terminates at the **next-next-hop** PE2.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 2.3 — Configure fast-reroute on the primary tunnel

Arm the primary `tunnel-te1` to actually *use* the bypass LSPs, requesting node protection.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 2.4 — Test with link failure (sub-50ms switchover)

Prove FRR delivers sub-50ms protection: run continuous traffic through `tunnel-te1`, fail the PE1→P1 link, count loss.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 2.5 — Protected vs unprotected adjacency-SID comparison (concept)

Contrast RSVP-TE FRR (this workbook) with SR TI-LFA using **protected vs unprotected adjacency-SIDs** (Workbook 09).


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 3 — Bandwidth Management

### Task 3.1 — RSVP bandwidth reservation on links

Reserve bandwidth for `tunnel-te1` and confirm RSVP decrements each link's reservable pool along the path.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 3.2 — Setup/hold priority (0–7)

Assign `tunnel-te1` a setup and hold priority so it can be positioned in the preemption hierarchy.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 3.3 — Preemption scenario (high-priority tunnel preempts low-priority)

Create a second tunnel `tunnel-te2` (PE1→PE2, same PE1→P1→PE2 path) with a **better** priority and enough bandwidth to force preemption of `tunnel-te1` when the link is congested.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 3.4 — Auto-bandwidth (measure and adjust)

Enable **auto-bandwidth** on `tunnel-te1` so it samples actual traffic and periodically resizes its reservation.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 4 — Advanced TE

### Task 4.1 — Make-before-break (SE style)

Reoptimize `tunnel-te1` onto a better path without dropping traffic, using **Shared-Explicit** reservation style.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 4.2 — DS-TE with MAM / RDM

Enable **DiffServ-Aware TE** so a sub-pool (e.g., voice/EF) has its own bandwidth accounting, and compare the **MAM** and **RDM** bandwidth-constraint models.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 4.3 — Affinity / admin-group (color bits)

Color links with **admin-groups** and constrain `tunnel-te1` to include/exclude specific colors via **affinity**.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 4.4 — CSPF constrained path computation

Add a fully **dynamic** path-option and observe **CSPF** honoring all constraints (bandwidth, affinity, TE metric) to compute the path — with no explicit hops.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 5 — TE + VPN Integration

### Task 5.1 — Autoroute announce with VPN (L3VPN traffic over TE tunnel)

Carry **VPNv4 (L3VPN)** customer traffic from PE1 to PE2 over `tunnel-te1` using autoroute announce, so the VPN label rides inside the TE LSP.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 5.2 — Per-VRF TE forwarding

Steer **only** VRF CUST_A over the TE tunnel while other VRFs / global traffic keep using LDP — using a **static route in the VRF** (or policy) pointing at the tunnel rather than global autoroute.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 5.3 — Forwarding-adjacency

Advertise `tunnel-te1` into IS-IS as a **real link** so *other* routers (not just PE1) can compute paths through it.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Section 6 — Troubleshooting

### Task 6.1 — Tunnel down: CSPF failed (insufficient bandwidth)

**Symptom:** `tunnel-te1` is DOWN; `show mpls traffic-eng tunnels tunnel-te1` reports "No path / CSPF: could not find a path".

**Diagnosis & Fix**

```
! Inspect why CSPF failed:
show mpls traffic-eng tunnels tunnel-te1 detail        ! look for "path error / no path"
show mpls traffic-eng topology                         ! check reservable BW on candidate links
show rsvp interface detail                             ! reserved vs available

! Common cause: signalled-bandwidth exceeds every path's reservable pool.
! Fix option A — lower the request:
interface tunnel-te1
 signalled-bandwidth 200000        ! was e.g. 1200000 > link capacity
!
! Fix option B — raise reservable BW on the links (if physically valid):
rsvp
 interface GigabitEthernet0/0/0/0
  bandwidth 1000000
```

CSPF prunes any link that can't satisfy the request **at the tunnel's setup priority**, so if the requested bandwidth exceeds the reservable pool on **every** feasible path, pruning leaves no route and CSPF returns "no path" — the tunnel never signals. This is a **head-end/control-plane** failure (no RSVP Path is even sent). Distinguish it from Task 6.2: here the failure is *local computation*, there it's *downstream signaling*. Fix by aligning the demand with capacity (lower `signalled-bandwidth`, raise link `bandwidth`, relax affinity, or add a looser fallback `path-option`).


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 6.2 — Tunnel down: RSVP Path Error (no route to destination)

**Symptom:** CSPF succeeds (or explicit path is set) but the tunnel stays DOWN with an RSVP **PathErr** — a mid-point or the tail can't forward the Path message.

**Diagnosis & Fix**

```
show mpls traffic-eng tunnels tunnel-te1 detail        ! "Path Error: routing problem / no route"
show rsvp session                                      ! where the Path stalls
show isis neighbors  /  show route 2.2.2.2             ! is the tail/next-hop actually reachable?

! Common cause: an explicit-path hop or the destination has no IGP route
! (e.g., IS-IS adjacency down on P1<->PE2, or wrong strict next-address).
! Fix — restore reachability / correct the explicit path:
router isis EMERALD
 interface GigabitEthernet0/0/0/2      ! P1<->PE2 link that was down
  no shutdown
!
! or correct a bad hop:
explicit-path name PE1_via_P1_to_PE2
 index 20 next-address strict ipv4 unicast 10.1.5.2    ! correct PE2 address
```

A **PathErr "no route to destination"** means RSVP's Path message reached a node that has no IGP route to the next explicit hop or to the tail — signaling can't proceed even though the head-end's CSPF (which used a possibly stale or explicit path) thought a path existed. Typical causes: a **strict** explicit hop pointing at an address that isn't directly connected, an IGP adjacency down along the path, or the tail loopback not in the IGP. Fix reachability (restore the adjacency, correct the `next-address`) so RSVP can walk the path to the tail and return Resv. This is a **downstream signaling** failure, distinct from Task 6.1's head-end CSPF failure.


> *Try this yourself first. Solution available in `solutions/` folder.*

### Task 6.3 — Tunnel UP but no traffic (missing autoroute announce)

**Symptom:** `tunnel-te1` shows UP/UP and RSVP is fully signaled, yet traffic to PE2 still takes the direct IGP link — the tunnel carries nothing.

**Diagnosis & Fix**

```
show mpls traffic-eng tunnels tunnel-te1 brief         ! UP/UP — control plane fine
show route 2.2.2.2                                     ! next-hop is the physical link, NOT tunnel-te1
show mpls traffic-eng autoroute                         ! (empty — nothing announced!)

! Root cause: the LSP is built but nothing tells the FIB to use it.
! Fix — add autoroute (or a static/FA) to attract traffic into the tunnel:
interface tunnel-te1
 autoroute announce
```

A signaled RSVP-TE LSP is just a **forwarding path that nothing points at** until you attract traffic into it. `autoroute announce`, a static route to `tunnel-te1`, or `forwarding-adjacency` are the mechanisms that put the tunnel into the RIB/FIB. Without one of them the tunnel is a "ghost" — perfectly UP, zero traffic. The tell-tale is a healthy `show mpls traffic-eng tunnels` combined with a `show route` whose next-hop is *not* the tunnel. This is the single most common "tunnel works but does nothing" issue.


> *Try this yourself first. Solution available in `solutions/` folder.*

