# SR-EX03: SR over LDP + LDP over SR Coexistence

**Platform:** IOS-XRv 9000
**Topology:** See [00_SR_topology_reference.md](./00_SR_topology_reference.md)
**Prerequisite:** SR-EX01 (SR-MPLS base) + SR-EX02 (prefix-SIDs / TI-LFA) complete

---

## End Goal

Build an **end-to-end labeled path from R1 (LDP domain) to R6 (SR domain)** that crosses the
LDP↔SR boundary at **R3**, in *both* directions:

- **LDP over SR (R1→R6):** R1 imposes an LDP label toward R3; R3 swaps to an SR label toward R6.
- **SR over LDP (R6→R1):** R1 has no prefix-SID, so R3 acts as a **Segment Routing Mapping Server (SRMS)**
  to advertise prefix-SIDs on R1/R2's behalf into IS-IS. R6 builds an SR path to R3, then R3 swaps
  to LDP toward R1.
- **Bidirectional traffic verified** (`ping` both ways, end-to-end).

The key insight of this lab: **R3 is a stitching point.** It is the only router that speaks both
label-distribution protocols, so every cross-domain LSP terminates and re-originates its label stack
at R3.

```
   LDP domain (OSPF)          R3 (boundary)              SR domain (IS-IS)
   R1 ---- R2 --------------- LDP + SR ---------------- R4 -- R5 -- R6
   172.16.1.1               172.16.3.3                          172.16.6.6
      |<----- LDP labels ----->|<-------- SR labels ---------->|
      |<----- LDP labels ------|<-------- SR labels (SRMS) ----|   (R6->R1 uses mapping server)
```

---

## Boundary Concept Cheat-Sheet

| Direction | Ingress protocol | Boundary action at R3 | Egress protocol | Needs SRMS? |
|-----------|------------------|-----------------------|-----------------|-------------|
| R1 → R6 (LDP over SR) | LDP | Swap LDP → SR | SR | No (R6 has native prefix-SID) |
| R6 → R1 (SR over LDP) | SR | Swap SR → LDP | LDP | **Yes** (R1/R2 have no prefix-SID) |

- **R6 has a native prefix-SID (16006)** — it is a real SR node, so the SR domain can reach it without help.
- **R1/R2 have NO prefix-SID** — they are LDP-only. For the SR domain to build a label path *to* them,
  someone must advertise a prefix-SID *on their behalf*. That someone is the **Mapping Server (R3)**.
- Reachability (the IP route) still needs to be leaked across the IGP boundary in *both* domains
  (mutual redistribution / BGP-LU). Labels alone don't create routes.

---

## Section 1 — Understanding the Boundary

### Task 1 — R3 runs BOTH LDP and SR

**Goal:** Confirm R3's forwarding table carries LDP labels (toward the OSPF/LDP domain) *and*
SR labels (toward the IS-IS/SR domain) at the same time.

R3 should already be configured from EX01/EX02. Confirm the coexistence config:

```
! R3 — boundary router (excerpt)
mpls ldp
 router-id 172.16.3.3
 interface GigabitEthernet0/0/0/0     ! R3<->R1  (LDP / OSPF domain)
 !
!
router isis SR
 net 49.0001.1720.1600.3003.00
 address-family ipv4 unicast
  metric-style wide
  segment-routing mpls
 !
 interface Loopback0
  address-family ipv4 unicast
   prefix-sid index 3
 !
 interface GigabitEthernet0/0/0/1     ! R3<->R6 (SR / IS-IS)
  point-to-point
  address-family ipv4 unicast
 !
 interface GigabitEthernet0/0/0/2     ! R3<->R4 (SR / IS-IS)
  point-to-point
  address-family ipv4 unicast
 !
 interface GigabitEthernet0/0/0/3     ! R3<->R5 (SR / IS-IS)
  point-to-point
  address-family ipv4 unicast
 !
```

**Verify — both label types present:**

```
RP/0/0/CPU0:R3# show mpls forwarding
```

Expected (abbreviated) — LDP-learned labels toward R1/R2, SR labels (16xxx) toward R4/R5/R6:

```
Local  Outgoing    Prefix             Outgoing     Next Hop        Bytes
Label  Label       or ID              Interface                    Switched
------ ----------- ------------------ ------------ --------------- ---------
24000  Pop         172.16.1.1/32      Gi0/0/0/0    10.0.13.1       0      <- LDP toward R1
24001  Pop         172.16.2.2/32      Gi0/0/0/0    10.0.13.1       0      <- LDP toward R2 (via R1/OSPF)
16004  Pop         172.16.4.4/32      Gi0/0/0/2    10.0.34.4       0      <- SR toward R4
16005  Pop         172.16.5.5/32      Gi0/0/0/3    10.0.35.5       0      <- SR toward R5
16006  Pop         172.16.6.6/32      Gi0/0/0/1    10.0.36.6       0      <- SR toward R6
```

**Confirm reachability from R3 to both edges:**

```
RP/0/0/CPU0:R3# ping 172.16.1.1        ! via LDP domain — should succeed
RP/0/0/CPU0:R3# ping 172.16.6.6        ! via SR domain  — should succeed
```

> **Why this matters:** R3 is the *only* node in the fabric with entries of both label families.
> Everything downstream in this lab is R3 stitching one family to the other.

---

### Task 2 — R6 (SR only) tries to reach R1 — no prefix-SID

**Goal:** Understand *why* R6 cannot natively build an SR path to R1.

```
RP/0/0/CPU0:R6# show isis segment-routing label table
```

Expected — SIDs exist for R3/R4/R5/R6 (native SR nodes) but **nothing for R1 (172.16.1.1) or R2**:

```
SID   Prefix/Mask          Interface/Node
16003 172.16.3.3/32        R3
16004 172.16.4.4/32        R4
16005 172.16.5.5/32        R5
16006 172.16.6.6/32        R6
   (no 172.16.1.1, no 172.16.2.2)
```

Also confirm R6 has no SR forwarding entry for R1:

```
RP/0/0/CPU0:R6# show mpls forwarding | include 172.16.1.1
   (empty)
```

**WHY (understand this):**
- R1 lives in the OSPF/LDP domain and runs **no IS-IS and no segment-routing**.
- Therefore R1 never advertises a prefix-SID into IS-IS.
- IS-IS SPF on R6 has no SID sub-TLV for `172.16.1.1/32`, so the SR label table has no entry.
- Even if the *IP route* to 172.16.1.1 were leaked into IS-IS (Task 3/4), a plain redistributed
  route carries **no prefix-SID** — so R6 still cannot impose an SR label for it.
- **Fix (Section 3):** a Mapping Server on R3 injects a prefix-SID *on R1's behalf* into IS-IS,
  giving R6 a SID to push.

---

### Task 3 — R1 (LDP only) tries to reach R6 — does LDP have a label?

**Goal:** Check whether R1 even has a route + LDP label for R6's loopback.

```
RP/0/0/CPU0:R1# show route 172.16.6.6
```

Likely result *before* redistribution — **route not present** (R6 is in IS-IS, R1 only knows OSPF):

```
% Network not in table
```

```
RP/0/0/CPU0:R1# show mpls ldp bindings 172.16.6.6/32
```

Expected — no binding, because LDP only creates label bindings for prefixes in the routing table:

```
   (no local or remote binding for 172.16.6.6/32)
```

**Check R3's redistribution state (root cause):**

```
RP/0/0/CPU0:R3# show run router ospf | include redistribute
RP/0/0/CPU0:R3# show run router isis SR | include redistribute
```

If nothing is returned, R3 is **not** leaking IS-IS→OSPF, so R1 can't learn R6, so LDP has nothing
to label. This is exactly what Section 2 fixes.

> **Key rule:** *LDP binds a label to a prefix only if that prefix is in the RIB.* No route ⇒ no LDP label.
> Cross-domain reachability is an **IGP redistribution** problem first, a labeling problem second.

---

## Section 2 — LDP over SR (R1 → R6 direction)

### Task 4 — Redistribute IS-IS → OSPF at the boundary so R1 learns R6

R3 must leak the SR-domain loopbacks (R4/R5/R6) into OSPF so R1/R2 get a route, then LDP will
bind labels to them automatically.

```
! R3 — leak IS-IS (SR domain) prefixes into OSPF (LDP domain)
route-policy ISIS_TO_OSPF
  if destination in (172.16.4.4/32, 172.16.5.5/32, 172.16.6.6/32) then
    pass
  endif
end-policy
!
router ospf CORE
 redistribute isis SR route-policy ISIS_TO_OSPF
!
```

> `route-policy` prevents leaking core /24 links and keeps the OSPF table clean — only loopbacks.
> Redistributed IS-IS routes appear as OSPF **E2** (external type-2) in R1's table.

**Data flow after this:** R1 gets an OSPF route to 172.16.6.6 with next-hop R3. LDP on R1 binds a
label and forwards labeled toward R3. R3 receives the LDP label, pops/swaps it, and imposes the
**SR label 16006** toward R6. That is *LDP over SR* — LDP in the access, SR in the core.

**Verify on R1:**

```
RP/0/0/CPU0:R1# show route 172.16.6.6
      O E2 172.16.6.6/32 [110/20] via 10.0.13.3, GigabitEthernet0/0/0/0

RP/0/0/CPU0:R1# show mpls ldp bindings 172.16.6.6/32
   172.16.6.6/32
     Local Binding:  Label: 24012
     Remote Binding: Label: 24007  Peer: 172.16.3.3:0    <- R3's LDP label
```

---

### Task 5 — Verify the label swap at R3 (traceroute mpls)

```
RP/0/0/CPU0:R1# traceroute mpls ipv4 172.16.6.6/32
```

Expected — LDP labels leaving R1, then SR labels (16xxx) once past R3:

```
  0 10.0.13.1  MRU 1500 [Labels: 24007  Exp: 0]        <- LDP label imposed by R1 toward R3
L 1 10.0.13.3  MRU 1500 [Labels: 16006  Exp: 0]  10 ms  <- R3 SWAPPED LDP -> SR (16006 for R6)
L 2 10.0.36.6  MRU 1500 [Labels: implicit-null] 10 ms   <- R6 PHP / egress
! 3 10.0.36.6  20 ms
```

**The swap at hop 1 (R3) is the whole point of this section:** ingress label family = LDP,
egress label family = SR. R3 is doing `LDP-in → SR-out`.

Confirm the swap in R3's forwarding table:

```
RP/0/0/CPU0:R3# show mpls forwarding prefix 172.16.6.6/32
Local  Outgoing   Prefix          Outgoing    Next Hop     Bytes
Label  Label      or ID           Interface                Switched
------ ---------- --------------- ----------- ------------ --------
24007  16006      172.16.6.6/32   Gi0/0/0/1   10.0.36.6    ...    <- incoming LDP 24007, outgoing SR 16006
```

---

### Task 6 — Test: ping R6 loopback sourced from R1 loopback

```
RP/0/0/CPU0:R1# ping 172.16.6.6 source 172.16.1.1
```

Expected:

```
Sending 5, 100-byte ICMP Echos to 172.16.6.6, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5)
```

**If it fails — troubleshoot in this order:**

1. **Route missing on R1** → `show route 172.16.6.6` empty ⇒ Task 4 redistribution/route-policy wrong.
2. **Return path missing** → R6 has no route back to 172.16.1.1 yet (that's Section 3). For a quick
   Section-2-only test, temporarily leak OSPF→IS-IS at R3 for R1/R2 loopbacks, or expect the ping to
   fail on the *return* leg until the mapping server is up. Confirm with:
   ```
   RP/0/0/CPU0:R6# show route 172.16.1.1     ! likely empty until Task 4b/Section 3
   ```
3. **Label swap wrong at R3** → `show mpls forwarding prefix 172.16.6.6/32` shows no outgoing SR label
   ⇒ SR not enabled toward R6 or IS-IS SID missing (revisit EX02).
4. **LDP session down** → `show mpls ldp neighbor` on R1 — R3 must be a neighbor.

> **Reality check:** a sourced ping needs a working path *both ways*. Section 2 gives you R1→R6.
> The return R6→R1 needs Section 3 (mapping server). Expect Task 6 to fully pass only after Task 10,
> unless you also leak OSPF→IS-IS for R1/R2 here. It is normal for the first attempt to show the
> forward LSP working (traceroute in Task 5) but the ping timing out on return.

**(Optional) Leak OSPF → IS-IS at R3 for the return route** (reachability only — still no SID):

```
! R3 — leak OSPF (LDP domain) loopbacks into IS-IS (SR domain)
route-policy OSPF_TO_ISIS
  if destination in (172.16.1.1/32, 172.16.2.2/32) then
    pass
  endif
end-policy
!
router isis SR
 address-family ipv4 unicast
  redistribute ospf CORE route-policy OSPF_TO_ISIS
!
```

This gives R6 an IP *route* to R1, but note: R6 still has **no SR label** for R1 until the mapping
server runs (that is precisely Task 7). Without a SID, R6 forwards toward R1 either unlabeled or via
the default/native path — which breaks a clean labeled LSP. The mapping server closes that gap.

---

## Section 3 — SR over LDP (R6 → R1 direction) — Mapping Server

### Task 7 — Configure the Mapping Server (SRMS) on R3

R1/R2 have no prefix-SID. R3 (the boundary) advertises SIDs *on their behalf* into IS-IS so the
whole SR domain can build label paths to the LDP-domain loopbacks.

```
! R3 — Segment Routing Mapping Server
segment-routing
 mapping-server
  prefix-sid-map
   address-family ipv4
    172.16.1.1/32 index 101       ! -> SR label 16101 for R1
    172.16.2.2/32 index 102       ! -> SR label 16102 for R2
   !
  !
 !
!
router isis SR
 address-family ipv4 unicast
  segment-routing prefix-sid-map advertise-local     ! advertise the SRMS mappings into IS-IS
 !
```

> **Index choice:** 101/102 sit outside the native node index range (3–6) to avoid collisions.
> Label = SRGB base (16000) + index ⇒ 16101 / 16102.
> `advertise-local` is what actually floods the mapping into IS-IS LSPs; without it the SRMS entries
> stay local to R3.

Also ensure R6 (and other SR nodes) are allowed to **receive/use** mapping-server entries. On IOS-XR
this is on by default (`segment-routing prefix-sid-map receive` is enabled unless disabled), but
verify if a node ignores mappings:

```
! On any SR client that should consume mappings (default = enabled)
router isis SR
 address-family ipv4 unicast
  segment-routing prefix-sid-map receive
```

---

### Task 8 — Verify the mapped SIDs propagated to R6

```
RP/0/0/CPU0:R6# show isis segment-routing label table
```

Expected — now includes **16101 (R1)** and **16102 (R2)** learned from the mapping server:

```
SID   Prefix/Mask          Interface/Node       Source
16003 172.16.3.3/32        R3                    Native
16004 172.16.4.4/32        R4                    Native
16005 172.16.5.5/32        R5                    Native
16006 172.16.6.6/32        R6                    Native
16101 172.16.1.1/32        (via R3)              SRMS (mapping-server)
16102 172.16.2.2/32        (via R3)              SRMS (mapping-server)
```

```
RP/0/0/CPU0:R6# show isis segment-routing prefix-sid-map active-policy
```

Expected:

```
SRMS active policy for IS-IS SR process
 Prefix               SID Index  Range   Flags
 172.16.1.1/32        101         1
 172.16.2.2/32        102         1
Number of mapping entries: 2
```

Also confirm the mapping server itself:

```
RP/0/0/CPU0:R3# show isis segment-routing prefix-sid-map active-policy
RP/0/0/CPU0:R3# show segment-routing mapping-server prefix-sid-map ipv4
```

---

### Task 9 — Verify the label path R6 → R1

```
RP/0/0/CPU0:R6# traceroute mpls ipv4 172.16.1.1/32
```

Expected — SR label (16101, the *mapped* SID) inside the IS-IS domain, then LDP labels after R3
swaps at the boundary:

```
  0 10.0.56.6  MRU 1500 [Labels: 16101 Exp: 0]         <- R6 imposes MAPPED SR label 16101
L 1 10.0.56.5  MRU 1500 [Labels: 16101 Exp: 0]  10 ms  <- R5 forwards SR (label unchanged, SPF path)
L 2 10.0.35.3  MRU 1500 [Labels: 24003 Exp: 0]  10 ms  <- R3 SWAPPED SR 16101 -> LDP 24003 toward R1
L 3 10.0.13.1  MRU 1500 [Labels: implicit-null] 10 ms  <- R1 egress / PHP
! 4 10.0.13.1  20 ms
```

Confirm the SR→LDP swap in R3's forwarding table:

```
RP/0/0/CPU0:R3# show mpls forwarding labels 16101
Local  Outgoing   Prefix          Outgoing    Next Hop     Bytes
Label  Label      or ID           Interface                Switched
------ ---------- --------------- ----------- ------------ --------
16101  24003      172.16.1.1/32   Gi0/0/0/0   10.0.13.1    ...    <- SR 16101 in, LDP 24003 out
```

> **This is *SR over LDP* stitched at R3:** SR label family in the core (via the mapping server SID),
> LDP label family in the access. Symmetric to Section 2, opposite direction.

---

### Task 10 — Test bidirectional end-to-end

```
RP/0/0/CPU0:R6# ping 172.16.1.1 source 172.16.6.6
RP/0/0/CPU0:R1# ping 172.16.6.6 source 172.16.1.1
```

Expected both directions:

```
!!!!!
Success rate is 100 percent (5/5)
```

**Now both LSPs exist:**
- R1→R6: LDP-over-SR (Section 2) — R1 learns R6 via OSPF redistribution, R3 swaps LDP→SR.
- R6→R1: SR-over-LDP (Section 3) — R6 learns R1's SID via SRMS, R3 swaps SR→LDP.

**If one direction still fails:**

| Symptom | Likely cause | Check |
|---------|--------------|-------|
| R6→R1 fails | SRMS mapping not received | `show isis segment-routing prefix-sid-map active-policy` on R6 (Task 8) |
| R6→R1 fails, SID present | R6 has SID but no IP route to R1 | `show route 172.16.1.1` on R6 (needs OSPF→IS-IS leak, Task 6 optional block) |
| R1→R6 fails | OSPF redistribution missing | `show route 172.16.6.6` on R1 (Task 4) |
| Both fail intermittently | asymmetric routing / mismatched SRGB | `show mpls label range` consistent (16000–23999) across all SR nodes |

---

## Section 4 — SR-Prefer and Migration Start

### Task 11 — Enable sr-prefer on R3

During migration, a prefix in the SR domain may be reachable via *both* an LDP label and an SR label.
`sr-prefer` tells the router to install the **SR** label as primary and keep LDP as backup — this is
the standard "SR takes over" migration knob.

```
! R3 — prefer SR labels over LDP for SR-domain destinations
router isis SR
 address-family ipv4 unicast
  segment-routing mpls sr-prefer
 !
!
```

> On IOS-XR the SR-prefer behavior for LDP coexistence is expressed under the IS-IS SR
> address-family. (Some releases also expose `segment-routing mpls sr-prefer` globally.)
> Effect: for a prefix with both an SR SID and an LDP binding, forwarding uses the SR label;
> the LDP path becomes a backup.

---

### Task 12 — Verify SR active, LDP backup (SR domain); LDP still primary (OSPF domain)

```
RP/0/0/CPU0:R3# show mpls forwarding
```

Expected — SR-domain destinations now forward via SR labels; OSPF-domain destinations still via LDP:

```
Local  Outgoing   Prefix           Outgoing    Next Hop      Notes
Label  Label      or ID            Interface
------ ---------- ---------------- ----------- ------------- ----------------------------
16006  Pop        172.16.6.6/32    Gi0/0/0/1   10.0.36.6     SR primary (sr-prefer)
16004  Pop        172.16.4.4/32    Gi0/0/0/2   10.0.34.4     SR primary
24000  Pop        172.16.1.1/32    Gi0/0/0/0   10.0.13.1     LDP (OSPF domain — unchanged)
24001  ...        172.16.2.2/32    Gi0/0/0/0   10.0.13.1     LDP (OSPF domain — unchanged)
```

Confirm the label preference explicitly:

```
RP/0/0/CPU0:R3# show mpls forwarding prefix 172.16.6.6/32 detail
   ... Label Stack {16006} ...  (SR)   [LDP path present as backup]
```

> **Migration meaning:** the SR domain now forwards on SR, LDP is just a safety net there. The OSPF
> (legacy) domain is untouched — LDP is still the only game in town for R1/R2 loopbacks.

---

### Task 13 — Remove LDP from R3's IS-IS interfaces (mixed mode)

Final migration step for this lab: stop running LDP on the SR-facing links (R3↔R4, R3↔R5, R3↔R6).
LDP stays only on R3↔R1 (the OSPF/legacy domain).

```
! R3 — remove LDP from SR-domain interfaces; keep it on the OSPF-domain interface
mpls ldp
 no interface GigabitEthernet0/0/0/1     ! R3<->R6  (was SR domain — LDP no longer needed)
 no interface GigabitEthernet0/0/0/2     ! R3<->R4
 no interface GigabitEthernet0/0/0/3     ! R3<->R5
 interface GigabitEthernet0/0/0/0        ! R3<->R1  (OSPF domain — KEEP LDP)
!
```

> If LDP was never explicitly enabled on those SR interfaces (SR domain typically doesn't run LDP),
> this step just confirms the state. In many EX01 builds LDP was only bound to Gi0/0/0/0 already.

**Verify LDP now only on the R1-facing link:**

```
RP/0/0/CPU0:R3# show mpls ldp interface brief
Interface           VRF          Config   Enabled   Neighbors
Gi0/0/0/0           default      Yes      Yes       1          <- R3<->R1 only
   (Gi0/0/0/1, Gi0/0/0/2, Gi0/0/0/3 no longer listed)

RP/0/0/CPU0:R3# show mpls ldp neighbor brief
Peer                State      ... 
172.16.1.1:0        Oper       ...    <- R1 only
```

**Verify SR handles all forwarding in the IS-IS domain:**

```
RP/0/0/CPU0:R3# show mpls forwarding | include Gi0/0/0/[123]
   ! all entries out the SR interfaces should carry 16xxx SR labels, no 24xxx LDP labels
```

**Confirm both cross-domain LSPs still work (mixed mode intact):**

```
RP/0/0/CPU0:R1# ping 172.16.6.6 source 172.16.1.1     ! LDP-over-SR still up
RP/0/0/CPU0:R6# ping 172.16.1.1 source 172.16.6.6     ! SR-over-LDP via SRMS still up
```

Both must remain `100 percent`. If R6→R1 breaks after removing LDP from SR links, the SRMS SID path
is doing the work now — re-verify Task 8/9. If R1→R6 breaks, the SR swap at R3 (Task 5) is the path.

---

## Completion Checklist

- [ ] **Task 1** — `show mpls forwarding` on R3 shows both LDP (24xxx) and SR (16xxx) labels; R3 pings R1 (LDP) and R6 (SR).
- [ ] **Task 2** — `show isis segment-routing label table` on R6 has no SID for 172.16.1.1; understand *why* (R1 advertises no prefix-SID into IS-IS).
- [ ] **Task 3** — `show mpls ldp bindings 172.16.6.6/32` on R1 empty; confirmed R3 not yet redistributing IS-IS→OSPF.
- [ ] **Task 4** — R3 redistributes IS-IS→OSPF (route-policy loopbacks only); R1 learns 172.16.6.6 as OSPF E2 and LDP binds a label.
- [ ] **Task 5** — `traceroute mpls` R1→R6 shows LDP label leaving R1, SR label 16006 after R3 (swap at R3 confirmed in `show mpls forwarding`).
- [ ] **Task 6** — `ping 172.16.6.6 source 172.16.1.1` from R1 (fully passes after Task 10 / return path up).
- [ ] **Task 7** — Mapping server configured on R3: 172.16.1.1/32→index 101, 172.16.2.2/32→index 102, `advertise-local` set.
- [ ] **Task 8** — R6 `show isis segment-routing label table` shows 16101 (R1) + 16102 (R2); `prefix-sid-map active-policy` lists both.
- [ ] **Task 9** — `traceroute mpls` R6→R1 shows mapped SR label 16101 in IS-IS domain, LDP label after R3 swap.
- [ ] **Task 10** — Bidirectional ping passes: R6→R1 (172.16.1.1) AND R1→R6 (172.16.6.6), both 100%.
- [ ] **Task 11** — `sr-prefer` enabled on R3 under IS-IS SR address-family.
- [ ] **Task 12** — `show mpls forwarding` on R3: SR labels primary for SR-domain prefixes (LDP backup); LDP still primary for OSPF-domain prefixes.
- [ ] **Task 13** — LDP removed from R3↔R4/R5/R6; LDP remains on R3↔R1; SR forwards the IS-IS domain; both cross-domain pings still 100%.

**Snapshot:** `SR-EX03-coexistence`

---

## Key Takeaways

1. **R3 is a label-stitching boundary.** Every cross-domain LSP terminates one label family and
   re-originates the other at R3 (`show mpls forwarding` shows the swap: LDP-in/SR-out or SR-in/LDP-out).
2. **LDP over SR needs only IGP redistribution** — R6 already has a native prefix-SID, so once R1 has a
   *route* (via IS-IS→OSPF leak), LDP labels it and R3 swaps to SR.
3. **SR over LDP needs a Mapping Server** — R1/R2 have no prefix-SID, so R3 (SRMS) advertises SIDs on
   their behalf (`prefix-sid-map ... index 101/102`, `advertise-local`). Label = SRGB + index (16101/16102).
4. **Reachability ≠ labeling.** A redistributed IP route gives reachability but carries no SID; the
   mapping server is what makes SR nodes able to *impose a label* toward LDP-only prefixes.
5. **`sr-prefer` drives migration** — SR becomes primary, LDP becomes backup, letting you decommission
   LDP link-by-link (Task 13) without dropping traffic. This is the standard SR migration pattern.
