# Lab 30: PCE & Centralized Path Computation — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 2 RRs, 6 CEs. Full MPLS-TE core with RSVP operational.
**Prerequisite:** Labs 3 and 16 complete (MPLS-TE tunnels working, SR-MPLS concepts understood)

**End Goal:** Deploy a Path Computation Element (PCE) architecture where a centralized PCE server computes optimal TE paths on behalf of Path Computation Clients (PCCs). Implement PCEP protocol, stateful PCE with delegation, PCE-initiated LSPs, high availability, and integration with SR-TE policies. By the end, you understand how PCE enables SDN-like centralized control while maintaining distributed forwarding.

**⚠️ Platform Note:** PCE/PCEP support on IOS 15.2 varies. Basic PCC functionality is available. Full stateful PCE server features may require IOS-XR or IOS-XE 16.x+. Where limitations exist, configuration is provided for reference.

---

## Section 1: PCE Architecture Fundamentals

### Task 1: Understand PCE/PCC Roles

1. **PCE (Path Computation Element):** centralized server with full network topology view
   - Computes constrained shortest paths (CSPF) for multiple head-ends
   - Has the Traffic Engineering Database (TED) of the entire network
   - Can compute paths across multiple IGP areas/domains
2. **PCC (Path Computation Client):** router requesting path computation
   - Sends path computation requests to PCE via PCEP
   - Receives computed EROs (Explicit Route Objects) from PCE
   - Signals the path locally (RSVP-TE or SR-TE)
3. **PCEP (Path Computation Element Protocol):** TCP-based (port 4189)
   - PCReq: PCC requests path computation
   - PCRep: PCE responds with computed path
   - PCUpd: stateful PCE pushes path updates
   - PCInit: PCE initiates new LSPs on PCC
4. Document: which router will be PCE in this lab? → R3 (central P router with full TED view)
5. Backup PCE: R7 (redundancy)
6. PCCs: R2, R8, R17, R18 (all PEs needing TE paths)

### Task 2: Enable PCE Server on R3

1. On R3: configure as PCE server:
   ```
   mpls traffic-eng pce server
    address ipv4 3.3.3.3
    peer-filter ipv4 access-list PCE-CLIENTS
   !
   ip access-list standard PCE-CLIENTS
    permit 2.2.2.2
    permit 8.8.8.8
    permit 17.17.17.17
    permit 18.18.18.18
   ```
2. Verify: `show mpls traffic-eng pce server` — PCE server active, listening on port 4189
3. Verify: `show tcp brief | include 4189` — TCP listener active
4. On R3: ensure Traffic Engineering Database is populated:
   ```
   show mpls traffic-eng topology
   ```
   - Should show ALL links in the network with TE attributes (bandwidth, affinity, metric)
5. **PCE requires TED:** without complete topology, PCE cannot compute valid paths
6. Verify: `show mpls traffic-eng topology brief` — all P and PE routers visible

### Task 3: Configure PCCs (Path Computation Clients)

1. On R2 (PCC): configure PCEP peer toward PCE (R3):
   ```
   mpls traffic-eng pce peer ipv4 3.3.3.3
    precedence 10
   mpls traffic-eng pce peer source ipv4 2.2.2.2
   ```
2. On R8 (PCC): same toward R3:
   ```
   mpls traffic-eng pce peer ipv4 3.3.3.3
    precedence 10
   mpls traffic-eng pce peer source ipv4 8.8.8.8
   ```
3. Repeat for R17 and R18
4. Verify: `show mpls traffic-eng pce peer` on R2 — peer state: "up"
5. Verify: `show mpls traffic-eng pce peer detail` — PCEP session statistics
6. On R3 (PCE): `show mpls traffic-eng pce peer` — all 4 PCC sessions visible
7. **Session verification:** TCP established on port 4189 between PCC and PCE

---

## Section 2: PCE-Computed Paths (Delegated Mode)

### Task 4: Create TE Tunnel with PCE Path Computation

1. On R2: create TE tunnel requesting path from PCE:
   ```
   interface Tunnel10
    ip unnumbered Loopback0
    tunnel mode mpls traffic-eng
    tunnel destination 8.8.8.8
    tunnel mpls traffic-eng path-option 10 dynamic pce
   ```
2. **Key: `path-option dynamic pce`** — tells router to ask PCE for the path instead of computing locally
3. Verify: `show mpls traffic-eng tunnels tunnel 10` — tunnel UP
4. Verify: `show mpls traffic-eng tunnels tunnel 10 detail | include path`
   - Path-option: "computed by PCE"
   - ERO shows the computed explicit route
5. On R3 (PCE): `show mpls traffic-eng pce peer detail` — path computation requests served
6. Compare with local CSPF: `path-option 20 dynamic` (local fallback)
7. Verify: with PCE available, path-option 10 (PCE) is preferred over path-option 20 (local)

### Task 5: PCE with Constraints

1. On R2: create constrained tunnel requesting PCE computation:
   ```
   interface Tunnel11
    ip unnumbered Loopback0
    tunnel mode mpls traffic-eng
    tunnel destination 17.17.17.17
    tunnel mpls traffic-eng bandwidth 50000
    tunnel mpls traffic-eng affinity 0x1 mask 0x1
    tunnel mpls traffic-eng path-option 10 dynamic pce
   ```
2. PCE computes path satisfying: bandwidth ≥ 50 Mbps AND affinity bit 0 set
3. Verify: `show mpls traffic-eng tunnels tunnel 11` — path satisfies constraints
4. Modify available bandwidth on a link → PCE recomputes path around congested link
5. On R3 (PCE): `show mpls traffic-eng topology` — verify bandwidth info is current
6. **PCE advantage:** PCE sees ALL tunnel reservations → global optimization possible
7. Local CSPF only knows local reservations → may make suboptimal choices

### Task 6: Path Computation with Diverse Paths (SRLG)

1. Request PCE to compute TWO diverse paths for primary and backup:
   ```
   interface Tunnel12
    tunnel destination 8.8.8.8
    tunnel mpls traffic-eng path-option 10 dynamic pce
   interface Tunnel13
    tunnel destination 8.8.8.8
    tunnel mpls traffic-eng path-option 10 dynamic pce
    tunnel mpls traffic-eng path-selection metric te
   ```
2. **PCE diversity:** PCE can compute link-diverse or SRLG-diverse path pairs
3. Verify: Tunnel12 and Tunnel13 take DIFFERENT physical paths
4. If PCE supports SVEC (Synchronized Vector): paths computed atomically as a pair
5. Without PCE: headend computes primary, then tries to compute diverse backup (may fail due to incomplete knowledge)
6. **PCE advantage for diversity:** global view ensures both paths are truly diverse
7. Verify: `show mpls traffic-eng tunnels brief` — both tunnels UP on different paths

---

## Section 3: Stateful PCE

### Task 7: Enable Stateful PCE (LSP State Synchronization)

1. **Stateless PCE (Section 2):** PCE computes on-demand — no memory of existing LSPs
2. **Stateful PCE:** PCE tracks ALL active LSPs in the network → can optimize globally
3. On R3 (PCE): enable stateful mode:
   ```
   mpls traffic-eng pce server
    stateful-client
     instantiation
     delegate
   ```
4. On R2 (PCC): enable stateful reporting:
   ```
   mpls traffic-eng pce stateful-client
    report
    delegate
   ```
5. Repeat on all PCCs (R8, R17, R18)
6. Verify: `show mpls traffic-eng pce peer detail` — "stateful" capability negotiated
7. On R3: `show mpls traffic-eng pce lsp` — ALL LSPs from all PCCs visible to PCE
8. **PCE now knows:** every TE tunnel in the network, their paths, and bandwidth reservations

### Task 8: LSP Delegation to PCE

1. On R2: delegate Tunnel10 to PCE for ongoing optimization:
   ```
   interface Tunnel10
    tunnel mpls traffic-eng path-option 10 dynamic pce
    tunnel mpls traffic-eng pce delegation
   ```
2. Verify: `show mpls traffic-eng tunnels tunnel 10` — "Delegated to PCE"
3. On R3 (PCE): verify delegation received:
   - `show mpls traffic-eng pce lsp detail` — tunnel marked as "delegated"
4. **Delegated LSP:** PCE can now MODIFY the path without PCC requesting it
5. PCE detects better path available → sends PCUpd message → PCC resignals LSP
6. Simulate: change IGP metric on a link → verify PCE pushes updated path to R2
7. Verify: `show mpls traffic-eng tunnels tunnel 10 detail` — path changed by PCE
8. **Revocation:** PCC can revoke delegation: `no tunnel mpls traffic-eng pce delegation`

### Task 9: PCE Global Optimization

1. Create multiple TE tunnels from different PEs — all delegated to PCE:
   - R2→R8 (Tunnel10), R2→R17 (Tunnel11)
   - R8→R2 (Tunnel20), R8→R18 (Tunnel21)
   - R17→R2 (Tunnel30)
2. All tunnels request 20 Mbps bandwidth
3. **Without PCE:** each headend computes independently → potential congestion on popular links
4. **With stateful PCE:** PCE distributes tunnels across links to balance load globally
5. On R3: `show mpls traffic-eng pce lsp` — all tunnels visible
6. Verify: tunnels spread across multiple paths (not all using same shortest path)
7. Modify one link's bandwidth to 30 Mbps (can only fit 1 tunnel) → PCE redistributes others
8. **This is the core PCE value proposition:** global optimization that headends cannot achieve alone

---

## Section 4: PCE-Initiated LSPs

### Task 10: PCE Creates LSPs on PCCs

1. **PCE-initiated:** PCE creates tunnels on PCCs without PCC requesting them
2. On R3 (PCE): initiate an LSP on R2:
   ```
   mpls traffic-eng pce initiate
    tunnel-te 50
     destination 8.8.8.8
     pcc ipv4 2.2.2.2
     bandwidth 10000
     path dynamic
   ```
3. Verify on R2: `show mpls traffic-eng tunnels tunnel 50` — tunnel created by PCE!
4. R2 did NOT configure this tunnel — PCE pushed it via PCInit message
5. Verify: `show mpls traffic-eng tunnels tunnel 50 detail` — "Initiated by PCE"
6. **Use case:** network controller provisions TE tunnels across the entire network from one place
7. On R3: remove the initiated tunnel → R2 tears it down
8. **SDN model:** PCE = controller, PCCs = forwarding nodes. Central provisioning.

### Task 11: PCE-Initiated with SR-TE (Segment List)

1. **PCE + SR-TE:** PCE computes segment list (label stack) and pushes to PCC
2. On R2 (PCC with SR enabled — from Lab 16):
   ```
   segment-routing traffic-eng
    pcc
     source-address ipv4 2.2.2.2
     pce address ipv4 3.3.3.3
      precedence 10
   ```
3. PCE initiates SR-TE policy on R2:
   ```
   ! On PCE (conceptual — actual config varies by platform):
   segment-routing traffic-eng
    pce
     initiate policy PE2-TO-PE8
      pcc ipv4 2.2.2.2
      color 100 end-point 8.8.8.8
      segment-list [16005, 16007, 16008]
   ```
4. Verify on R2: `show segment-routing traffic-eng policy` — policy created by PCE
5. **Advantage:** PCE computes the segment list globally → no RSVP state on transit routers
6. Verify: traffic from R2 to R8 follows the PCE-computed segment list
7. **Modern SP architecture:** PCE + SR-TE = SDN control plane with MPLS data plane

### Task 12: Bandwidth-on-Demand via PCE

1. **Concept:** application requests bandwidth → PCE provisions tunnel automatically
2. Simulate: configure on-demand tunnel request via PCE when VPN traffic appears:
   ```
   segment-routing traffic-eng
    on-demand color 100
     dynamic
      pce
   ```
3. When BGP next-hop + color 100 appears: PCC asks PCE to compute path → PCE responds with ERO/segment-list
4. Verify: add VPN route with color 100 → SR-TE policy auto-created via PCE computation
5. Remove route → policy torn down
6. **Automation:** no pre-provisioned tunnels — PCE creates them on-demand as traffic patterns change
7. **Scalability:** with 1000 VPN prefixes × different colors: PCE handles computation, PCC handles forwarding

---

## Section 5: PCE High Availability

### Task 13: Redundant PCE Deployment

1. On R7: configure as backup PCE server:
   ```
   mpls traffic-eng pce server
    address ipv4 7.7.7.7
    peer-filter ipv4 access-list PCE-CLIENTS
   ```
2. On all PCCs: configure primary AND backup PCE:
   ```
   mpls traffic-eng pce peer ipv4 3.3.3.3
    precedence 10
   mpls traffic-eng pce peer ipv4 7.7.7.7
    precedence 20
   ```
   (Lower precedence = preferred → R3 is primary, R7 is backup)
3. Verify: `show mpls traffic-eng pce peer` — R3 active, R7 standby
4. Shut R3's Loopback0 → PCEP session to R3 drops
5. Verify: PCCs fail over to R7 within PCEP keepalive timer (default 30s)
6. Verify: `show mpls traffic-eng pce peer` on R2 — R7 now active
7. Bring R3 back → verify reversion to R3 (lower precedence)
8. **Measure:** tunnel convergence during PCE failover — tunnels should remain UP (using last computed path)

### Task 14: PCE State Synchronization

1. **Problem:** when R7 takes over from R3, it has no knowledge of delegated LSPs
2. **Solution:** PCE state sync — R3 and R7 synchronize LSP state
3. On R3 and R7: enable PCE state sync:
   ```
   mpls traffic-eng pce server
    state-sync peer 7.7.7.7
   !
   ! On R7:
   mpls traffic-eng pce server
    state-sync peer 3.3.3.3
   ```
4. Verify: `show mpls traffic-eng pce state-sync` — synchronized LSP database
5. Fail over to R7 → verify R7 immediately knows all delegated LSPs (no re-learning needed)
6. **Without state sync:** backup PCE must wait for PCCs to re-report all LSPs → slower recovery
7. Verify: delegated tunnels can be immediately optimized by backup PCE after failover

### Task 15: PCE Failure — Local Fallback

1. Kill BOTH PCEs (R3 and R7) — all PCEP sessions down
2. On R2: `show mpls traffic-eng tunnels tunnel 10` — tunnel should remain UP
3. **Fallback:** PCC uses last known path, or falls back to local computation:
   ```
   tunnel mpls traffic-eng path-option 10 dynamic pce
   tunnel mpls traffic-eng path-option 20 dynamic
   ```
4. Path-option 20 (local CSPF) takes over when PCE is unavailable
5. Verify: tunnel resignals using local computation
6. Bring PCEs back → verify tunnel redelegates to PCE
7. **Design principle:** PCE enhances path selection but is NOT a single point of failure
8. Network continues forwarding traffic even with total PCE loss

---

## CCIE+ Challenges

### Challenge 1: Multi-Domain PCE (Hierarchical)

1. **Scenario:** two IGP areas — each has local PCE, one parent PCE coordinates
2. Configure area-specific PCEs:
   - R3: PCE for Area 0 (core)
   - R7: PCE for Area 1 (south region)
3. Configure hierarchical PCE:
   - R3 is parent PCE
   - R7 reports to R3 for inter-area path computation
4. Request cross-area tunnel (R2 in Area 0 → R18 in Area 1):
   - R2 asks R3 → R3 cooperates with R7 → stitched ERO returned
5. Verify: tunnel path crosses area boundary using cooperatively computed path
6. **Real-world:** each domain (AS/area) has its own PCE; parent PCE coordinates inter-domain paths

### Challenge 2: PCE with Bandwidth Calendaring

1. **Concept:** schedule bandwidth reservations for future time windows
2. Configure time-based tunnel:
   - Tunnel12: 100 Mbps during business hours (8am-6pm)
   - Tunnel12: 10 Mbps during off-hours
3. PCE adjusts path computation based on time-of-day bandwidth matrix
4. Verify: PCE pushes path update when bandwidth window changes
5. **Use case:** SP sells "premium bandwidth during business hours" — PCE automates provisioning

### Challenge 3: PCE for RSVP-to-SR Migration

1. Current state: RSVP-TE tunnels computed by PCE
2. Migration goal: replace RSVP-TE with SR-TE policies computed by same PCE
3. On PCE: support both RSVP path computation AND SR-TE segment list computation
4. Migrate one tunnel at a time:
   - Remove RSVP tunnel on R2
   - PCE initiates equivalent SR-TE policy
5. Verify: traffic continues flowing — no outage during migration
6. **PCE as migration enabler:** same controller, different data plane (RSVP → SR)

### Challenge 4: PCEP Extensions — FlowSpec via PCE

1. **Concept:** PCE pushes traffic steering rules (FlowSpec-like) to PCCs
2. PCE decides: "traffic matching source 10.1.0.0/16 should use Tunnel10"
3. PCE sends steering instruction to R2 via PCEP
4. R2 installs policy: matching traffic → Tunnel10
5. Verify: traffic steered according to PCE instruction
6. **SDN vision:** PCE controls not just path computation but also traffic classification
7. Document: which PCEP extensions enable this (draft-ietf-pce-pcep-flowspec)

---

## Final Validation

By the end of this lab, your network has:

- [ ] PCE server operational on R3 with full TED visibility
- [ ] PCEP sessions established from all PEs (PCCs) to PCE
- [ ] TE tunnels computed by PCE (path-option dynamic pce)
- [ ] Constrained path computation (bandwidth + affinity) via PCE
- [ ] Diverse path pair computation using PCE global view
- [ ] Stateful PCE tracking all LSPs in the network
- [ ] LSP delegation — PCE modifying paths proactively
- [ ] Global optimization distributing tunnels across links
- [ ] PCE-initiated LSPs created on PCCs without local config
- [ ] PCE + SR-TE integration (segment list computation)
- [ ] Bandwidth-on-demand provisioned via PCE
- [ ] Redundant PCE (R3 primary, R7 backup) with failover tested
- [ ] PCE state synchronization for seamless failover
- [ ] Local computation fallback when PCE is unavailable
- [ ] (CCIE+) Multi-domain/hierarchical PCE concept documented
- [ ] (CCIE+) PCE as RSVP-to-SR migration enabler
