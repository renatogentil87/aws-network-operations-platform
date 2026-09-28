# SR-EX05: SR L3VPN End-to-End (across LDP + SR domains)

**Platform:** IOS-XRv 9000
**Topology:** See [00_SR_topology_reference.md](00_SR_topology_reference.md)
**Prerequisite:** SR-EX01 + SR-EX03 complete (LDP↔SR coexistence working)
**Snapshot:** `SR-EX05-l3vpn`

---

## End Goal

Build an L3VPN from **CE1** (dual-homed to R1/R2 in the LDP/OSPF domain) to **CE2**
(single-homed to R6 in the SR/IS-IS domain). Achieve full VPN connectivity across the
**LDP↔SR boundary at R3**, then validate resilience with TI-LFA and path steering with
Flex-Algo.

```
        LDP Domain (OSPF + LDP)          │        SR Domain (IS-IS + SR-MPLS)
                                         │
  CE1 ==(eBGP 65001)== R1 ── R3(boundary) ── R4 ── R5 ── R6 ==(eBGP 65002)== CE2
       (dual-homed)  ── R2 ──┘  RR/VPNv4        (P)  (P)   (PE)
                                         │
   VPN label distributed by BGP VPNv4; transport = LDP west of R3, SR east of R3.
   R3 performs the transport-label swap (LDP label ↔ SR prefix-SID) at the boundary.
```

**Key design points**
- **R3** is the boundary PE-facing reflector: BGP VPNv4 Route Reflector for R1, R2, R6.
- Transport LSP is stitched at R3 (LDP↔SR) — already working from SR-EX01/EX03.
- The **VPN (service) label** is end-to-end via BGP; only the **transport (outer) label**
  changes character at R3.

---

## VPN Parameters (quick reference)

| Item | Value |
|------|-------|
| Provider AS | 65100 |
| VRF name | `CUSTOMER` |
| Route Distinguisher (per-PE) | `<PE-loopback-ish>:100` (RD unique per PE) |
| Route Target (import/export) | `65100:100` |
| CE1 AS | 65001 (dual-homed to R1 + R2) |
| CE2 AS | 65002 (single-homed to R6) |
| Route policy | `PASS-ALL` (permit everything, in + out) |

> **RD vs RT:** RD makes prefixes unique on the wire; make it unique per PE
> (`65100:1`, `65100:2`, `65100:6`). RT controls import/export and MUST be the
> **same** (`65100:100`) on all three PEs so routes cross the VPN.

---

## Section 1 — BGP VPNv4 Setup (4 tasks)

### Task 1 — R3 as Route Reflector (VPNv4)

R3 (`172.16.3.3`) reflects VPNv4 routes between the two edge PEs (R1, R2) and the far PE (R6).

```
! ===== R3 (172.16.3.3) — RR for VPNv4 =====
route-policy PASS-ALL
  pass
end-policy
!
router bgp 65100
 bgp router-id 172.16.3.3
 address-family vpnv4 unicast
 !
 ! --- R1 (RR client) ---
 neighbor 172.16.1.1
  remote-as 65100
  update-source Loopback0
  address-family vpnv4 unicast
   route-reflector-client
  !
 !
 ! --- R2 (RR client) ---
 neighbor 172.16.2.2
  remote-as 65100
  update-source Loopback0
  address-family vpnv4 unicast
   route-reflector-client
  !
 !
 ! --- R6 (RR client) ---
 neighbor 172.16.6.6
  remote-as 65100
  update-source Loopback0
  address-family vpnv4 unicast
   route-reflector-client
  !
 !
!
commit
```

> R3 has no VRF of its own here — it is a pure RR/transit for the VPNv4 AF. Because it
> already carries the stitched LDP↔SR transport LSPs, reflected VPN routes resolve
> end-to-end.

---

### Task 2 — VRF CUSTOMER on R1 (PE for CE1 e1)

```
! ===== R1 (172.16.1.1) — PE, VRF CUSTOMER =====
route-policy PASS-ALL
  pass
end-policy
!
vrf CUSTOMER
 address-family ipv4 unicast
  import route-target
   65100:100
  !
  export route-target
   65100:100
  !
 !
!
! --- PE-CE interface: Gi0/0/0/1 (NIC3) toward CE1 e1, 192.168.1.0/24 ---
interface GigabitEthernet0/0/0/1
 vrf CUSTOMER
 ipv4 address 192.168.1.1 255.255.255.0
 no shutdown
!
router bgp 65100
 bgp router-id 172.16.1.1
 address-family vpnv4 unicast
 !
 ! --- iBGP toward RR (R3) ---
 neighbor 172.16.3.3
  remote-as 65100
  update-source Loopback0
  address-family vpnv4 unicast
  !
 !
 ! --- VRF: eBGP toward CE1 (AS 65001) ---
 vrf CUSTOMER
  rd 65100:1
  address-family ipv4 unicast
   redistribute connected
  !
  neighbor 192.168.1.2
   remote-as 65001
   address-family ipv4 unicast
    route-policy PASS-ALL in
    route-policy PASS-ALL out
   !
  !
 !
!
commit
```

---

### Task 3 — VRF CUSTOMER on R2 (PE for CE1 e2, dual-homed)

Same RT (`65100:100`), unique RD. CE1 is the **same AS (65001)** on both R1 and R2, so
R2 needs **`as-override`** so CE1 accepts routes that were originated by the other CE1
link (its own ASN would otherwise be rejected by the AS-path loop check).

```
! ===== R2 (172.16.2.2) — PE, VRF CUSTOMER (CE1 dual-homed) =====
route-policy PASS-ALL
  pass
end-policy
!
vrf CUSTOMER
 address-family ipv4 unicast
  import route-target
   65100:100
  !
  export route-target
   65100:100
  !
 !
!
! --- PE-CE interface: Gi0/0/0/1 (NIC3) toward CE1 e2, 192.168.2.0/24 ---
interface GigabitEthernet0/0/0/1
 vrf CUSTOMER
 ipv4 address 192.168.2.1 255.255.255.0
 no shutdown
!
router bgp 65100
 bgp router-id 172.16.2.2
 address-family vpnv4 unicast
 !
 ! --- iBGP toward RR (R3) ---
 neighbor 172.16.3.3
  remote-as 65100
  update-source Loopback0
  address-family vpnv4 unicast
  !
 !
 ! --- VRF: eBGP toward CE1 (AS 65001) ---
 vrf CUSTOMER
  rd 65100:2
  address-family ipv4 unicast
   redistribute connected
  !
  neighbor 192.168.2.2
   remote-as 65001
   address-family ipv4 unicast
    route-policy PASS-ALL in
    route-policy PASS-ALL out
    as-override
   !
  !
 !
!
commit
```

> **Why `as-override` here?** CE1 sits in AS 65001 on both R1 and R2. When R2 advertises
> a prefix that CE1 originally sourced (learned via R1 → RR → R2), the AS-path contains
> 65001. Without `as-override`, CE1's inbound loop-prevention drops it. `as-override`
> rewrites the peer AS (65001) in the AS-path with the provider AS (65100) so CE1 accepts
> it. (Alternative: `allowas-in` on the CE — but `as-override` is the PE-side fix and is
> what this task specifies.)

---

### Task 4 — VRF CUSTOMER on R6 (PE for CE2)

Same RT (`65100:100`), unique RD. CE2 is a different customer AS (65002), so no
`as-override` needed.

```
! ===== R6 (172.16.6.6) — PE, VRF CUSTOMER =====
route-policy PASS-ALL
  pass
end-policy
!
vrf CUSTOMER
 address-family ipv4 unicast
  import route-target
   65100:100
  !
  export route-target
   65100:100
  !
 !
!
! --- PE-CE interface: Gi0/0/0/0 (NIC2) toward CE2 e1, 192.168.6.0/24 ---
interface GigabitEthernet0/0/0/0
 vrf CUSTOMER
 ipv4 address 192.168.6.1 255.255.255.0
 no shutdown
!
router bgp 65100
 bgp router-id 172.16.6.6
 address-family vpnv4 unicast
 !
 ! --- iBGP toward RR (R3) ---
 neighbor 172.16.3.3
  remote-as 65100
  update-source Loopback0
  address-family vpnv4 unicast
  !
 !
 ! --- VRF: eBGP toward CE2 (AS 65002) ---
 vrf CUSTOMER
  rd 65100:6
  address-family ipv4 unicast
   redistribute connected
  !
  neighbor 192.168.6.2
   remote-as 65002
   address-family ipv4 unicast
    route-policy PASS-ALL in
    route-policy PASS-ALL out
   !
  !
 !
!
commit
```

> **CE side (reference, Arista vEOS):** CE1 advertises `10.1.1.0/24` toward R1 (192.168.1.1)
> and R2 (192.168.2.1) in AS 65001; CE2 advertises `10.2.2.0/24` toward R6 (192.168.6.1)
> in AS 65002. Use loopbacks `10.1.1.1/32` (CE1) and `10.2.2.2/32` (CE2) plus a
> `network`/`redistribute connected` for the customer subnet.

---

## Section 2 — End-to-End VPN Verification (4 tasks)

### Task 5 — VPNv4 sessions on R3 (RR)

```
RP/0/0/CPU0:R3# show bgp vpnv4 unicast summary
```

**Expect:** neighbors `172.16.1.1` (R1), `172.16.2.2` (R2), `172.16.6.6` (R6) all in
`Established` state (State/PfxRcd shows a number, not `Idle`/`Active`/`Connect`).

```
Neighbor        Spk    AS  MsgRcvd MsgSent   TblVer  InQ OutQ  Up/Down  St/PfxRcd
172.16.1.1        0 65100      ...     ...      ...    0    0  00:0x:xx          2
172.16.2.2        0 65100      ...     ...      ...    0    0  00:0x:xx          2
172.16.6.6        0 65100      ...     ...      ...    0    0  00:0x:xx          1
```

Also confirm reflection is happening:

```
RP/0/0/CPU0:R3# show bgp vpnv4 unicast
! Should list CE1's prefixes (RD 65100:1 and 65100:2) and CE2's prefix (RD 65100:6)
```

---

### Task 6 — CE1 routes reach R6

```
RP/0/0/CPU0:R6# show bgp vrf CUSTOMER ipv4 unicast
RP/0/0/CPU0:R6# show route vrf CUSTOMER 10.1.1.0/24
```

**Expect:** CE1's prefix (`10.1.1.0/24`, and the PE-CE subnets) present in the VRF with
**next-hop 172.16.1.1 (R1)** and/or **172.16.2.2 (R2)** — dual-homed, so you should see
both paths (one best, one backup).

```
RP/0/0/CPU0:R6# show bgp vrf CUSTOMER 10.1.1.0/24
! Paths: (2 available, best #1)
!   Local, imported ...
!     172.16.1.1 (metric ...) from 172.16.3.3 (172.16.1.1)   <-- via R1, reflected by R3
!   Local, imported ...
!     172.16.2.2 (metric ...) from 172.16.3.3 (172.16.2.2)   <-- via R2, reflected by R3
```

Confirm the transport resolves over SR (east of R3):

```
RP/0/0/CPU0:R6# show cef vrf CUSTOMER 10.1.1.0/24 detail
! local label + outgoing SR transport label (16003 toward R3 boundary) expected
```

---

### Task 7 — CE2 routes reach R1/R2

```
RP/0/0/CPU0:R1# show bgp vrf CUSTOMER ipv4 unicast
RP/0/0/CPU0:R1# show route vrf CUSTOMER 10.2.2.0/24
```

**Expect:** CE2's prefix (`10.2.2.0/24`) present in R1's VRF with **next-hop 172.16.6.6 (R6)**,
learned from RR `172.16.3.3`.

```
RP/0/0/CPU0:R1# show bgp vrf CUSTOMER 10.2.2.0/24
! Paths: (1 available, best #1)
!   Local, imported ...
!     172.16.6.6 (metric ...) from 172.16.3.3 (172.16.6.6)   <-- via R6, reflected by R3
```

Confirm the transport resolves over LDP (west of R3):

```
RP/0/0/CPU0:R1# show cef vrf CUSTOMER 10.2.2.0/24 detail
! outgoing LDP transport label toward R3 expected
```

Repeat on R2 to confirm dual-homed PE also has the route.

---

### Task 8 — End-to-end data plane (CE1 → CE2)

**Ping from CE1:**

```
CE1# ping 10.2.2.2 source 10.1.1.1
! Expect !!!!! (100% success)
```

**Traceroute from CE1 (label stack visible):**

```
CE1# traceroute 10.2.2.2 source 10.1.1.1
```

**Expect the label character to change at R3 (the boundary):**

```
 1  192.168.1.1  [R1]                              <-- CE-PE hop
 2  10.0.13.x    [R3]  MPLS Label=<LDP-label>/<VPN-label>   <-- LDP transport (OSPF domain)
 3  10.0.34.x    [R4]  MPLS Label=16006/<VPN-label>         <-- SR transport (IS-IS domain)
 4  10.0.45.x    [R5]  MPLS Label=16006/<VPN-label>         <-- SR prefix-SID to R6
 5  192.168.6.2  [CE2]                             <-- PE-CE hop, VPN label popped at R6
```

**What to observe / narrate for the exam:**
- West of R3: **LDP** transport label (dynamically assigned, e.g. `24xxx`).
- At R3: transport label is **swapped LDP → SR prefix-SID** (`16006` = R6's SID). The VPN
  (service) label is untouched — it is end-to-end.
- East of R3: **SR** transport label = `16006` (R6 prefix-SID from SRGB 16000+).
- The **label swap at R3 is the whole point** — confirm with:

```
RP/0/0/CPU0:R3# show mpls forwarding
! Look for an entry that receives an LDP local label and forwards with SR label 16006 (to R6)
RP/0/0/CPU0:R3# show mpls forwarding prefix 172.16.6.6/32 detail
```

---

## Section 3 — VPN + TI-LFA (3 tasks)

> Prereq: TI-LFA enabled in the SR/IS-IS domain (from SR-EX03). If not:
> ```
> router isis 1
>  interface GigabitEthernet0/0/0/x
>   address-family ipv4 unicast
>    fast-reroute per-prefix
>    fast-reroute per-prefix ti-lfa
> ```

### Task 9 — Link failure in the SR domain (TI-LFA)

Start a continuous ping and cut the direct R3↔R6 link.

```
CE1# ping 10.2.2.2 source 10.1.1.1 repeat 100000
```

```
! On R3 — shut the direct link to R6 (Gi0/0/0/1 = NIC3, 10.0.36.0/24)
RP/0/0/CPU0:R3(config)# interface GigabitEthernet0/0/0/1
RP/0/0/CPU0:R3(config-if)# shutdown
RP/0/0/CPU0:R3(config-if)# commit
```

**Expect:** 0–1 packet lost. TI-LFA pre-computed a repair path, so VPN traffic reroutes
**R3 → R4 → R5 → R6** almost instantly.

```
RP/0/0/CPU0:R3# show isis fast-reroute 172.16.6.6/32 detail
RP/0/0/CPU0:R3# show cef 172.16.6.6/32 detail
! backup path via R4 with a repair label stack (node/adjacency SIDs)
```

Re-run traceroute from CE1 — path now traverses R4/R5 before R6.

**Restore:** `no shutdown` on R3 Gi0/0/0/1, `commit`.

---

### Task 10 — Node failure (shut R5 entirely)

```
CE1# ping 10.2.2.2 source 10.1.1.1 repeat 100000
```

```
! Simulate R5 node failure — shut all core links on R5
RP/0/0/CPU0:R5(config)# interface GigabitEthernet0/0/0/1
RP/0/0/CPU0:R5(config-if)# shutdown
RP/0/0/CPU0:R5(config-if)# interface GigabitEthernet0/0/0/2
RP/0/0/CPU0:R5(config-if)# shutdown
RP/0/0/CPU0:R5(config-if)# interface GigabitEthernet0/0/0/3
RP/0/0/CPU0:R5(config-if)# shutdown
RP/0/0/CPU0:R5(config-if)# commit
```

**Expect:** CE1↔CE2 still works. **Node protection** (TI-LFA computes a repair that avoids
the failed *node*, not just the link) reroutes around R5 — e.g. `R3 → R4 → R6` or
`R3 → R6` (direct, if restored). Verify:

```
RP/0/0/CPU0:R3# show isis fast-reroute 172.16.6.6/32 detail
! "Node protection" should be indicated on the backup
RP/0/0/CPU0:R4# show cef 172.16.6.6/32 detail
```

**Restore:** `no shutdown` all three R5 interfaces, `commit`. Confirm IS-IS adjacencies
re-form (`show isis adjacency`).

---

### Task 11 — CEF VRF detail on R6 (repair segments)

```
RP/0/0/CPU0:R6# show cef vrf CUSTOMER 10.1.1.0/24 detail
```

**Expect:** primary path (toward R3 via SR) **and** a backup path with **repair segments**
(a label stack of node/adjacency SIDs describing the TI-LFA detour). Look for:
- `via ... , protected`
- `repair: ...` with an outgoing label list
- both a primary and a backup next-hop / label stack

```
RP/0/0/CPU0:R6# show cef vrf CUSTOMER 10.1.1.0/24 detail
!   10.1.1.0/24, version ..., ...
!     local label ...
!     via 172.16.3.3, ..., protected              <-- primary
!       next hop ... labels imposed {16003 <VPN>}
!     via <backup>, ..., backup (remote)           <-- TI-LFA backup
!       repair: ... labels {<repair-SIDs> 16003 <VPN>}
```

---

## Section 4 — VPN + Flex-Algo Steering (3 tasks)

> **Conditional:** only if **SR-EX04** (Flex-Algo 128 = delay-optimized) was completed and
> the delay-optimized topology (Algo 128) is defined + advertised in the SR domain.

### Task 12 — Steer CE2's VPN traffic onto Flex-Algo 128 (ODN)

Approach: R6 tags CE2's VPN routes with a **BGP color** community; the ingress PEs (R1/R2)
match that color with an **On-Demand Next-hop (ODN)** SR-TE policy that requests a path
computed on **algo 128** (low-delay).

```
! ===== R6 — color CE2's routes (export a color community) =====
route-policy SET-COLOR-128
  set extcommunity color COLOR-128
  pass
end-policy
!
extcommunity-set opaque COLOR-128
  128
end-set
!
router bgp 65100
 vrf CUSTOMER
  neighbor 192.168.6.2
   address-family ipv4 unicast
    route-policy SET-COLOR-128 in     ! color routes learned from CE2
   !
  !
 !
!
commit
```

```
! ===== R1 (and R2) — ODN template: color 128 -> SR-TE path on algo 128 =====
segment-routing
 traffic-eng
  on-demand color 128
   dynamic
    metric
     type delay
    !
   !
   ! constrain path to Flex-Algo 128
   sid-algorithm 128
  !
 !
!
commit
```

> When R1/R2 receive a VPNv4 route with **color 128** and next-hop R6, ODN auto-instantiates
> an SR-TE policy to R6 whose path is computed using the **delay metric on algo 128**. The
> VPN service label rides that colored SR-TE LSP instead of the default (algo 0) transport.

---

### Task 13 — Verify Algo-128 steering

```
RP/0/0/CPU0:R1# show segment-routing traffic-eng policy color 128
! An on-demand policy to endpoint 172.16.6.6, color 128, Admin/Oper UP,
! with a segment list built from algo-128 SIDs.

RP/0/0/CPU0:R1# show bgp vrf CUSTOMER 10.2.2.0/24
! Route to CE2 shows Color:128 and resolves onto the SR-TE policy (binding-SID).
```

**Traceroute follows the low-delay path:**

```
RP/0/0/CPU0:R1# traceroute vrf CUSTOMER 10.2.2.2 source <VRF-loopback-or-CE-facing>
! Path should differ from Task 8's default (algo 0) path — it now follows the
! delay-optimized algo-128 topology through the SR domain.
```

Compare against the Task 8 baseline traceroute to prove the path changed.

---

### Task 14 — Remove color → revert to Algo 0

```
! ===== R6 — stop coloring CE2's routes =====
route-policy SET-COLOR-128
  pass
end-policy
!
! (or remove the inbound policy entirely)
router bgp 65100
 vrf CUSTOMER
  neighbor 192.168.6.2
   address-family ipv4 unicast
    no route-policy SET-COLOR-128 in
    route-policy PASS-ALL in
   !
  !
 !
!
commit
```

**Expect:** with no color, R1/R2 no longer instantiate the ODN policy; the route to
`10.2.2.0/24` resolves over the **default algo-0** transport again.

```
RP/0/0/CPU0:R1# show segment-routing traffic-eng policy color 128
! Policy should be gone (or Down / no longer referenced).
RP/0/0/CPU0:R1# traceroute vrf CUSTOMER 10.2.2.2
! Path matches the Task 8 default (algo 0) path again.
```

---

## Completion Checklist

**Section 1 — BGP VPNv4 Setup**
- [ ] Task 1 — R3 RR configured; VPNv4 AF; R1/R2/R6 as RR clients, `update-source Loopback0`
- [ ] Task 2 — VRF CUSTOMER on R1 (rd 65100:1, rt 65100:100); Gi0/0/0/1 in VRF; eBGP CE1 AS 65001; PASS-ALL in/out
- [ ] Task 3 — VRF CUSTOMER on R2 (rd 65100:2, rt 65100:100); Gi0/0/0/1 in VRF; eBGP CE1 AS 65001; `as-override`; PASS-ALL
- [ ] Task 4 — VRF CUSTOMER on R6 (rd 65100:6, rt 65100:100); Gi0/0/0/0 in VRF; eBGP CE2 AS 65002; PASS-ALL

**Section 2 — End-to-End VPN Verification**
- [ ] Task 5 — `show bgp vpnv4 unicast summary` on R3: R1/R2/R6 Established
- [ ] Task 6 — `show bgp vrf CUSTOMER` on R6: CE1 prefixes, next-hop R1/R2
- [ ] Task 7 — `show bgp vrf CUSTOMER` on R1: CE2 prefixes, next-hop R6
- [ ] Task 8 — CE1 ping CE2 OK; traceroute shows LDP labels R1→R3, SR labels R3→R4/R5→R6; R3 label swap visible

**Section 3 — VPN + TI-LFA**
- [ ] Task 9 — Shut R3↔R6 link; TI-LFA reroute R3→R4→R5→R6; 0–1 packet loss
- [ ] Task 10 — Shut R5 (node failure); node protection reroutes; CE1↔CE2 still works
- [ ] Task 11 — `show cef vrf CUSTOMER detail` on R6: primary + backup paths with repair segments

**Section 4 — VPN + Flex-Algo Steering (if SR-EX04 done)**
- [ ] Task 12 — Color 128 on CE2 routes (R6); ODN SR-TE policy on R1/R2 matching color → algo 128
- [ ] Task 13 — `traceroute vrf CUSTOMER` R1→CE2 follows algo-128 (low-delay) path
- [ ] Task 14 — Remove color; traffic reverts to default algo-0 path

**Snapshot:** `SR-EX05-l3vpn`

---

## Troubleshooting Notes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| VPNv4 session stuck Idle/Active | Loopback not reachable / wrong `update-source` | Verify IGP + `show bgp vpnv4 unicast summary`; `update-source Loopback0` on both ends |
| Routes in `show bgp vpnv4` but not in VRF | RT import/export mismatch | All PEs must import+export `65100:100` |
| CE1 rejects routes from the "other" CE1 link | AS-path loop (same AS 65001) | `as-override` on R2 (Task 3), or `allowas-in` on CE1 |
| Ping fails but VPNv4 route present | Transport LSP not resolving across boundary | Re-check SR-EX01/EX03 LDP↔SR stitching; `show mpls forwarding` on R3 |
| No label swap seen at R3 | R3 not both LDP+SR or missing prefix-SID | Confirm R3 runs OSPF+LDP and IS-IS+SR; `show mpls forwarding prefix 172.16.6.6/32` |
| TI-LFA no backup | FRR/TI-LFA not enabled on IS-IS interfaces | `fast-reroute per-prefix ti-lfa` under IS-IS AF |
| ODN policy never comes up | Color not set, or algo 128 not advertised | `show bgp vrf CUSTOMER <pfx>` for Color; confirm SR-EX04 algo 128 present |
