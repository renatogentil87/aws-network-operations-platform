# Lab 1: MPLS Forwarding Basics — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs (R2, R8, R17, R18), 9 P routers (R3-R7, R13-R16), 7 CEs
**Prerequisite:** GNS3 topology built with all physical links connected

**End Goal:** An MPLS-enabled SP core where all PE and P routers have OSPF adjacencies, LDP sessions, and MPLS label switching. By the end, traffic between PE loopbacks traverses the core using label switching instead of IP forwarding — the foundation for every subsequent lab.

**Status: ✅ COMPLETED** — This lab represents the base state of your GNS3 topology. OSPF area 0 + LDP + MPLS are already running on all core routers.

---

## Section 1: IGP Foundation (OSPF Area 0)

### Task 1: Configure OSPF on All Core Routers - done

1. On ALL P and PE routers (R2-R8, R13-R18): configure OSPF process 1, area 0
2. Advertise all core-facing interfaces into OSPF area 0
3. Advertise Loopback0 into OSPF area 0 (passive interface)
4. Do NOT enable OSPF on PE-CE interfaces (CEs are not part of SP IGP)
5. Verify: `show ip ospf neighbor` on every router — all adjacencies FULL
6. Verify: `show ip route ospf` on R2 — all PE and P loopbacks reachable
7. Verify: R2 can ping R8 (8.8.8.8), R17 (17.17.17.17), R18 (18.18.18.18) — all PE loopbacks

### Task 2: Verify Full IGP Reachability - done

1. From R2: ping every P router loopback (3.3.3.3 through 7.7.7.7, 13.13.13.13 through 16.16.16.16)
2. From R17: ping R2 (2.2.2.2) and R8 (8.8.8.8) — verify cross-topology reachability
3. Verify: `show ip ospf database router` — all 13 router LSAs present
4. This confirms: the IGP is fully converged and every router knows how to reach every other router via IP

---

## Section 2: Enable MPLS and LDP

### Task 3: Enable MPLS on Core Interfaces - done

1. On ALL P and PE routers: `mpls ip` on every core-facing interface
2. On ALL P and PE routers: `mpls label protocol ldp` (global, if not default)
3. On ALL routers: configure label ranges (R2=200-299, R3=300-399, etc.) for easy identification
4. Do NOT enable MPLS on PE-CE interfaces
5. Verify: `show mpls interfaces` on every router — all core interfaces show "Yes" for MPLS

### Task 4: Verify LDP Sessions - done

1. On R2: `show mpls ldp neighbor` — LDP sessions to R3 and R6 (directly connected P routers)
2. On R3: `show mpls ldp neighbor` — sessions to R2, R4, R6, R7
3. Verify: every router has LDP sessions with all directly connected core neighbors
4. Verify: `show mpls ldp bindings` on R2 — labels allocated for all loopback prefixes
5. Key observation: LDP assigns a LOCAL label for every IGP route and advertises it to neighbors

### Task 5: Verify Label Switching Path - done

1. On R2: `show mpls forwarding-table 8.8.8.8 32` — note the outgoing label and interface
2. On each hop toward R8: `show mpls forwarding-table 8.8.8.8 32` — trace the label swaps
3. Identify: where does PHP (Penultimate Hop Popping) occur? (The router one hop before R8 pops the label)
4. On the PHP router: outgoing label shows "Pop" or "implicit-null"
5. Traceroute from R2 to R8: `traceroute 8.8.8.8` — observe MPLS labels in the output
6. Verify: the forwarding path uses labels (not IP lookup) on every hop except the last

---

## Section 3: Understand the MPLS Data Plane

### Task 6: Label Operations - done

1. On R2 (ingress PE): packets to 8.8.8.8 get a label PUSHED (encapsulation)
2. On P routers (transit): labels are SWAPPED (old label → new label)
3. On penultimate hop (before R8): label is POPPED (PHP — exposes IP header)
4. On R8 (egress PE): receives normal IP packet — does IP lookup
5. Verify each operation:
   - R2: `show ip cef 8.8.8.8` — shows "label push" action
   - R3: `show mpls forwarding-table` — shows "swap" action for R8's label
   - Penultimate router: shows "pop" action
6. Draw the label path on paper — this is the foundation for ALL MPLS services

### Task 7: CEF and LFIB Relationship - done

1. On R2: `show ip cef 8.8.8.8` — CEF table says "use label X, send to interface Y"
2. On R3: `show mpls forwarding-table labels X` — LFIB says "swap label X to label Z, send to interface W"
3. Key insight: ingress PE uses CEF (IP → label). Transit routers use LFIB (label → label). These are separate tables.
4. On R3: `show ip cef 8.8.8.8` — R3 ALSO has a CEF entry, but MPLS traffic never hits it (LFIB takes priority for labeled packets)
5. Verify: P routers forward labeled traffic WITHOUT doing IP lookup

---

## Final Validation

By the end of this lab, your network has:

- [x] OSPF area 0 running on all 13 core routers (PEs + P routers)
- [x] All PE and P loopbacks reachable via OSPF
- [x] MPLS enabled on all core interfaces (not PE-CE)
- [x] LDP sessions established between all directly connected core neighbors
- [x] Labels allocated for every loopback prefix
- [x] Label switching verified hop-by-hop (push → swap → swap → pop)
- [x] PHP occurring on penultimate hop
- [x] CEF (IP lookup) at ingress, LFIB (label lookup) at transit — understood
- [x] Label ranges configured per router for easy debugging
