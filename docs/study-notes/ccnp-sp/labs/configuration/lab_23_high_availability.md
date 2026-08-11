# Lab 23: High Availability — NSR, NSF, Graceful Restart & Fast Convergence — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — same physical topology
**Prerequisite:** Labs 1-2 complete (OSPF + LDP + L3VPN running)

**End Goal:** A hardened SP network where control-plane failures (process crash, RP switchover, software upgrade) do NOT cause forwarding-plane outages. By the end, you understand how Tier-1 SPs achieve 99.999% availability using NSF, GR, BFD, LDP session protection, and fast convergence tuning — and how these mechanisms interact.

**Note:** Some HA features (NSR, SSO, ISSU) require dual-RP hardware not available on the 7200 platform. These are documented conceptually with verification commands for exam readiness. Features that DO work on 7200 (Graceful Restart, BFD, LDP protection, timer tuning) are fully configurable.

---

## Topology Adaptation

No topology changes. Use existing 20-router topology with OSPF + LDP + L3VPN operational. The focus is adding HA features on top of the working network.

Key routers for HA testing:
- **R5** (P router, central path): primary target for GR/NSF testing
- **R3, R7** (RR): BGP Graceful Restart testing
- **R2, R8** (PE): VPN service continuity during failures

---

## Section 1: Understanding the HA Framework

### Task 1: Document the HA Architecture

1. Map the three planes and their HA mechanisms:

| Plane | What Fails | HA Mechanism | Result |
|---|---|---|---|
| Management Plane | SSH/SNMP/CLI access lost | SSO (Stateful Switchover) | Management recovers, no traffic impact |
| Control Plane | OSPF/BGP/LDP process crash | NSF + Graceful Restart | Forwarding continues on stale state |
| Data Plane | Linecard/ASIC failure | FRR, ECMP, redundant paths | Traffic reroutes in <50ms |

2. Document the relationship:
   - **SSO:** hardware-level — backup RP takes over from active RP
   - **NSF:** software-level — forwarding plane keeps working during control plane restart
   - **GR:** protocol-level — neighbors don't tear down adjacency during restart
   - **NSR:** ultimate goal — neighbors don't even KNOW a restart happened

3. No configuration — conceptual understanding for exam.

### Task 2: Verify Current Convergence Baseline

1. Start continuous ping from R1 to R9: `ping 9.9.9.9 repeat 10000 timeout 1`
2. On R5 (transit P router): `clear ip ospf process` — forces OSPF restart
3. Count dropped pings — this is your BASELINE convergence time without HA
4. Restart LDP on R5: `clear mpls ldp neighbor *`
5. Count dropped pings — measure LDP reconvergence impact
6. On R3 (RR): `clear ip bgp * soft` — measure BGP impact on VPN traffic
7. Document all three baseline numbers — we'll improve them throughout this lab

---

## Section 2: OSPF Graceful Restart (RFC 3623)

### Task 3: Enable OSPF Graceful Restart (NSF-aware)

1. On R5: enable NSF awareness (helper mode — assists restarting neighbors):
   ```
   router ospf 1
    nsf ietf helper
   ```
2. On ALL other P/PE routers: enable same (everyone must be NSF-aware to help)
3. Verify: `show ip ospf` — look for "NSF helper support enabled"
4. On R5: enable NSF capability (this router can restart gracefully):
   ```
   router ospf 1
    nsf ietf
   ```
5. Verify: `show ip ospf nsf` — shows NSF state

### Task 4: Test OSPF Graceful Restart

1. Start continuous ping from R1 to R9 (through R5)
2. On R5: `clear ip ospf process` (simulates OSPF process restart)
3. Observe: neighbors of R5 enter "helper mode" — they DON'T tear down adjacency
4. Verify on R3: `show ip ospf neighbor` — R5 shows state as FULL during entire restart
5. Count dropped pings — should be 0-2 (vs baseline of 5-10 without GR)
6. Verify: `show ip ospf nsf` on R5 — shows "last NSF restart successful"
7. Key: forwarding table on R5 remained intact during OSPF restart — no traffic loss

### Task 5: OSPF Graceful Restart Failure Scenarios

1. Test: shut an interface on R5 DURING the graceful restart period
2. Result: GR is aborted — helper neighbor detects topology change and flushes
3. Verify: traffic drops during this scenario (GR can't protect against real failures)
4. Key lesson: GR protects against planned restarts, NOT actual network failures
5. For actual failures: use FRR (Lab 3 Challenge 1) or LFA (next section)

---

## Section 3: BGP Graceful Restart

### Task 6: Enable BGP Graceful Restart on All Routers

1. On all PE and RR routers:
   ```
   router bgp 64512
    bgp graceful-restart
    bgp graceful-restart restart-time 120
    bgp graceful-restart stalepath-time 360
   ```
2. Verify: `show ip bgp neighbors <IP> | include Graceful` — shows GR capability advertised
3. Parameters:
   - `restart-time 120`: how long neighbor waits before declaring session dead (2 min)
   - `stalepath-time 360`: how long to keep stale routes in RIB during restart (6 min)

### Task 7: Test BGP Graceful Restart

1. Start continuous ping from R1 to R9 (VPN traffic through BGP control plane)
2. On R3 (RR): `clear ip bgp *` (simulates BGP process restart)
3. Observe on R2: `show ip bgp vpnv4 all summary` — R3 session shows "(restart)"
4. Observe: VPN routes remain in R2's table with "(stale)" flag
5. Count dropped pings: should be 0 (forwarding continues on stale routes)
6. After R3's BGP reconverges: stale flag removed, routes refreshed
7. Verify: `show ip bgp vpnv4 all 9.9.9.9` — route has no stale flag after recovery

### Task 8: BGP GR with Restart Timer Expiry

1. On R3: shut the interface toward R2 (simulate permanent failure, not restart)
2. R2 enters "GR wait" mode — holds stale routes for `restart-time` seconds
3. After 120 seconds: R2 declares restart failed, purges stale routes
4. VPN traffic reroutes to R7 (backup RR)
5. This demonstrates: GR provides a GRACE PERIOD, not infinite waiting
6. Verify: `show ip bgp vpnv4 all summary` on R2 — R3 session eventually drops, R7 takes over

---

## Section 4: LDP Graceful Restart & Session Protection

### Task 9: LDP Graceful Restart

1. On all P/PE routers:
   ```
   mpls ldp graceful-restart
   mpls ldp graceful-restart timers neighbor-liveness 120
   mpls ldp graceful-restart timers max-recovery 120
   ```
2. Verify: `show mpls ldp graceful-restart` — shows GR enabled
3. Test: on R5, `clear mpls ldp neighbor *`
4. Observe: LDP sessions flap but LFIB retains labels during restart
5. Verify: `show mpls forwarding-table` on R5 — labels remain (stale) during restart
6. Traffic continues forwarding on stale labels until LDP reconverges

### Task 10: LDP Session Protection

1. On all P/PE routers:
   ```
   mpls ldp session protection duration 90
   ```
2. On routers with targeted-hello capability:
   ```
   mpls ldp discovery targeted-hello accept
   ```
3. Test: shut a link between R5 and R8 (direct LDP session drops)
4. Verify: `show mpls ldp neighbor 8.8.8.8` on R5 — session stays UP via alternate path (targeted hello)
5. Labels for FECs via R8 remain valid in LFIB — no traffic loss
6. Bring link back → LDP session returns to direct (drops targeted)
7. Key: LDP session protection maintains the SESSION even when the direct link fails, as long as an alternate IGP path exists

### Task 11: LDP-IGP Synchronization

1. On all P/PE routers under OSPF:
   ```
   router ospf 1
    mpls ldp sync
   ```
2. Test: remove `mpls ip` from R5's Gi2/0 (breaks LDP on that link)
3. Observe: `show ip ospf interface Gi2/0` on R5 — OSPF advertises MAX metric on that link
4. Result: OSPF traffic avoids the link where LDP is broken → no MPLS blackhole
5. Restore `mpls ip` → OSPF metric returns to normal → traffic uses the link again
6. Verify: `show mpls ldp igp sync` — all interfaces show "Sync achieved"

---

## Section 5: BFD (Bidirectional Forwarding Detection)

### Task 12: BFD for OSPF

1. On all core interfaces:
   ```
   interface GigabitEthernet1/0
    bfd interval 100 min_rx 100 multiplier 3
   ```
2. Under OSPF:
   ```
   router ospf 1
    bfd all-interfaces
   ```
3. Verify: `show bfd neighbors` — BFD sessions UP on all OSPF interfaces
4. Test: simulate link degradation (interface goes DOWN)
5. Observe: BFD detects failure in 300ms (3 × 100ms) vs OSPF dead-timer of 40 seconds
6. OSPF reacts to BFD event → SPF runs → convergence in <500ms total

### Task 13: BFD for LDP

1. Under LDP:
   ```
   mpls ldp discovery hello interval 5
   mpls ldp discovery hello holdtime 15
   ```
2. Associate BFD with LDP:
   ```
   mpls ldp neighbor <IP> targeted bfd
   ```
   (Or use IGP-triggered BFD which covers LDP automatically on IOS)
3. Verify: when BFD detects failure, LDP session drops immediately (not waiting for LDP holdtime)
4. Combined with LDP-IGP sync: BFD detects failure → LDP drops → OSPF max-metric → traffic reroutes

### Task 14: BFD for BGP

1. On PE routers for eBGP sessions:
   ```
   router bgp 64512
    neighbor 192.168.12.1 fall-over bfd
   ```
2. Verify: `show ip bgp neighbors 192.168.12.1 | include BFD`
3. Test: break connectivity to CE → BFD detects in 300ms → BGP session drops immediately
4. Without BFD: BGP hold-timer (180s default) determines detection time — 3 minutes!
5. With BFD: 300ms detection — 360x faster

---

## Section 6: Fast Convergence Integration

### Task 15: Complete Fast Convergence Stack

1. Document the full convergence timeline WITH all HA features:
   ```
   Detection: BFD 300ms (or interface down = instant)
   → OSPF SPF: 50ms (throttle timer)
   → LSA flooding: 50ms (throttle timer)
   → LDP update: follows OSPF (IGP sync ensures no blackhole)
   → BGP reconvergence: follows IGP (next-hop changes)
   → FRR (if TE): sub-50ms (pre-computed backup)
   
   Total: 300-500ms for non-FRR, <50ms for FRR
   ```

2. Compare with NO HA features:
   ```
   Detection: OSPF dead-timer 40s (or LDP holdtime 15s)
   → OSPF SPF: 5s (default throttle)
   → LSA flooding: 5s
   → LDP: 90s (default holdtime)
   → BGP: 180s (default hold-timer)
   
   Total: 40-180 seconds!
   ```

3. Verify your network has ALL components in place:
   - `show bfd neighbors` — all sessions UP
   - `show ip ospf | include SPF` — throttle 50/200/5000
   - `show mpls ldp igp sync` — all achieved
   - `show mpls ldp graceful-restart` — enabled
   - `show ip bgp neighbors <IP> | include Graceful|BFD` — both active

### Task 16: Full Failure Simulation

1. Start pings from R1 to R9 AND R12 to R11 simultaneously (two VPN customers)
2. Shut R5's Gi2/0 (link toward R8) — breaks primary path
3. Measure: how many pings lost? Target: ≤3 (≤6 seconds with BFD 100ms × 3 + SPF 50ms)
4. Bring link back — measure: how fast does traffic return?
5. Repeat: shut R3 completely (simulates node failure affecting RR)
6. Measure: VPN traffic should survive (R7 backup RR holds routes via BGP GR)
7. Document results vs baseline from Task 2

---

## Section 7: ISSU and SSO Concepts (Theory)

### Task 17: Understand ISSU (In-Service Software Upgrade)

1. Document ISSU requirements:
   - Dual RP (Route Processor) — not available on 7200
   - SSO (Stateful Switchover) between active and standby RP
   - NSF (Non-Stop Forwarding) during RP switchover
   - Compatible IOS versions (ISSU compatibility matrix)
   
2. ISSU process:
   ```
   Step 1: Load new IOS on standby RP
   Step 2: Switchover — standby becomes active (SSO)
   Step 3: Forwarding continues (NSF) while new active RP initializes
   Step 4: Load new IOS on old active (now standby)
   Step 5: Both RPs now running new IOS — zero traffic loss
   ```

3. Platforms that support ISSU:
   - ASR 9000 (IOS-XR)
   - ASR 1000 (IOS-XE)
   - NCS 5500 (IOS-XR)
   - CRS (IOS-XR)
   - NOT: 7200, ISR, CSR1000v

### Task 18: Understand NSR (Non-Stop Routing)

1. NSR vs NSF/GR:
   - **NSF/GR:** neighbors KNOW you restarted (they enter helper mode)
   - **NSR:** neighbors DON'T KNOW you restarted (hot-standby RP maintains all protocol state)
   
2. NSR is superior because:
   - No dependency on neighbor supporting GR
   - No risk of GR timer expiry during slow reconvergence
   - Works even if neighbor is a third-party device without GR support

3. NSR configuration (IOS-XR example for exam):
   ```
   router ospf 1
    nsr
   router bgp 64512
    nsr
   mpls ldp
    nsr
   ```

4. Verify concept: after RP switchover with NSR, `show ip ospf neighbor` shows ALL adjacencies remain FULL with uninterrupted uptime

---

## CCIE+ Challenges

### Challenge 1: LFA (Loop-Free Alternate) for IP Fast Reroute

1. Enable IP FRR with LFA on all OSPF interfaces:
   ```
   router ospf 1
    fast-reroute per-prefix enable area 0
   ```
2. Verify: `show ip ospf fast-reroute` — backup paths pre-computed
3. Test: shut a link — traffic switches to LFA backup in <50ms
4. Compare: LFA is for IP/LDP traffic; TE FRR (Lab 3) is for TE tunnel traffic
5. When to use which: LFA for non-TE networks; FRR for TE-enabled networks

### Challenge 2: Remote LFA (rLFA)

1. Problem: basic LFA can't always find a loop-free backup (topology-dependent)
2. Solution: rLFA creates a targeted LDP session to a "PQ node" for backup
3. Configure: `fast-reroute per-prefix enable area 0` + `fast-reroute per-prefix remote-lfa tunnel mpls-ldp`
4. Verify: `show ip ospf fast-reroute` — shows remote LFA tunnels where basic LFA is unavailable
5. Coverage improvement: basic LFA covers ~80% of prefixes; rLFA covers ~95%

### Challenge 3: TI-LFA (Topology Independent LFA) Concept

1. SR networks use TI-LFA instead of LFA/rLFA
2. TI-LFA provides 100% coverage (any topology, any failure)
3. Uses segment routing label stacks to encode the post-convergence path as backup
4. No pre-signaled tunnels needed (unlike TE FRR)
5. Document: how TI-LFA constructs the backup label stack for a specific failure scenario
6. Lab this on EVE-NG with IOS-XRv (Lab 16 extension)

### Challenge 4: BGP PIC (Prefix Independent Convergence)

1. Pre-install backup BGP path in CEF:
   ```
   router bgp 64512
    address-family vpnv4
     bgp additional-paths install
   ```
2. When primary path fails: CEF switches to backup instantly (no BGP reconvergence needed)
3. Convergence: from seconds → sub-second for VPN prefix failover
4. Verify: `show ip cef vrf Customer_A <prefix> internal` — shows backup path installed

### Challenge 5: Comprehensive HA Audit

1. Create a checklist script that verifies ALL HA features are enabled:
   - BFD on all OSPF interfaces
   - SPF/LSA throttle timers set to 50/200/5000
   - LDP GR enabled
   - LDP session protection enabled
   - LDP-IGP sync enabled
   - BGP GR enabled with proper timers
   - BFD for BGP on all eBGP sessions
   - OSPF NSF helper enabled
2. Run against all 13 P/PE routers
3. Output: PASS/FAIL per router per feature
4. This is what SP NOC teams run after every maintenance window

---

## Final Validation

By the end of this lab, your network has:

- [ ] OSPF Graceful Restart (NSF) — 0 packet loss during OSPF process restart
- [ ] BGP Graceful Restart — VPN routes maintained during BGP restart
- [ ] LDP Graceful Restart — labels maintained during LDP restart
- [ ] LDP Session Protection — LDP survives direct link failure
- [ ] LDP-IGP Synchronization — no MPLS blackholes during convergence
- [ ] BFD on all OSPF/LDP/BGP sessions — 300ms detection
- [ ] Fast convergence tuning — sub-second total convergence
- [ ] (Theory) ISSU, SSO, NSR concepts understood for exam
- [ ] (CCIE+) LFA, rLFA, TI-LFA, BGP PIC for sub-50ms protection
