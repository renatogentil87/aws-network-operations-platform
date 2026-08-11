# Lab 24: Network Timing & Synchronization — PTP & SyncE — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2) — mostly conceptual/theory
**Topology:** 20 routers — same physical topology
**Prerequisite:** Lab 1 complete (OSPF + LDP running)

**End Goal:** Understand how SPs distribute precise timing (frequency and phase) across packet networks for mobile backhaul (4G/5G), financial trading, and broadcast services. By the end, you know PTP (IEEE 1588v2), SyncE, clock hierarchies, and how they're deployed in SP networks — critical SPCOR exam content.

**Important:** PTP and SyncE require specialized hardware (GPS receivers, PTP-capable NICs, SyncE-capable interfaces). The Cisco 7200 in GNS3 does NOT support these features. This lab is **conceptual + configuration reference** for exam preparation. Actual testing requires ASR 9000, NCS, or similar hardware.

---

## Topology Adaptation

Conceptual mapping of timing roles onto your 20-router topology:

```
GPS Grandmaster Clock: R3 (connected to GPS antenna — primary reference)
Boundary Clocks: R4, R5, R6, R7 (P routers — relay timing)
Slave Clocks: R2, R8, R17, R18 (PE routers — need precise time for CE services)
CEs (end clients): R1, R9, R19, R20 (cell towers, base stations)

Timing Flow: GPS → R3 → R4/R5/R6/R7 → R2/R8/R17/R18 → CEs
```

---

## Section 1: Why Timing Matters in SP Networks

### Task 1: Understand Timing Requirements

1. Document why different services need precise timing:

| Service | Frequency Sync | Phase/Time Sync | Accuracy |
|---|---|---|---|
| TDM (legacy T1/E1) | ✅ Required | ❌ Not needed | ±50 ppb |
| 4G LTE (FDD) | ✅ Required | ❌ Not needed | ±50 ppb |
| 4G LTE (TDD) | ✅ Required | ✅ Required | ±1.5 μs |
| 5G NR (TDD) | ✅ Required | ✅ Required | ±130 ns |
| Financial trading | ❌ Not critical | ✅ Required | ±1 μs |
| Broadcast video | ✅ Required | ✅ Required | ±1 μs |

2. Key definitions:
   - **Frequency synchronization:** all clocks tick at the same RATE (same bps)
   - **Phase synchronization:** all clocks agree on the same TIME (same timestamp)
   - **Time-of-Day (ToD):** absolute wall-clock time (UTC)

3. SP challenge: replace TDM (inherently synchronous) with packet networks (asynchronous) without losing timing accuracy

### Task 2: Clock Hierarchy (ITU-T G.811/G.812/G.813)

1. Document the clock stratum/quality levels:

| Quality Level | ITU-T | Description | Accuracy | Example |
|---|---|---|---|---|
| PRC | G.811 | Primary Reference Clock | ±1×10⁻¹¹ | GPS/Cesium |
| SSU-A | G.812 Type I | Sync Supply Unit (transit) | ±1×10⁻⁹ | Core router |
| SSU-B | G.812 Type IV | Sync Supply Unit (local) | ±2×10⁻⁸ | Access router |
| SEC | G.813 Option 1 | SDH Equipment Clock | ±4.6×10⁻⁶ | End equipment |
| DNU | — | Do Not Use | — | Free-running |

2. Clock selection priority: always use the BEST available source
3. If GPS fails: fall back to next-best source (holdover mode)
4. ESMC (Ethernet Synchronization Messaging Channel) carries quality levels between SyncE nodes

---

## Section 2: SyncE (Synchronous Ethernet — ITU-T G.8261/G.8262)

### Task 3: Understand SyncE Architecture

1. SyncE = physical layer frequency synchronization over Ethernet
2. How it works:
   - Traditional Ethernet: each device has its own local oscillator (free-running)
   - SyncE: device LOCKS its local oscillator to the frequency received on a specific port
   - Result: frequency is carried hop-by-hop, physical layer, deterministic — like TDM
   
3. Components:
   - **PRC (Primary Reference Clock):** GPS or Cesium source
   - **EEC (Ethernet Equipment Clock):** the clock on each SyncE-capable router
   - **ESMC (Ethernet Sync Messaging Channel):** slow protocol frames carrying SSM (Sync Status Message)
   - **SSM/QL (Sync Status Message / Quality Level):** tells downstream what quality the clock is

4. SyncE does NOT carry phase/time — only frequency. For phase, you need PTP.

### Task 4: SyncE Configuration Reference

1. Configuration on a SyncE-capable router (ASR 9000 / NCS example):
   ```
   ! Select the clock source
   clock-interface sync 0
    port-parameters
     gps-input
    frequency synchronization
     selection input
     priority 1
     wait-to-restore 0
   
   ! Enable SyncE on an interface
   interface TenGigE0/0/0/0
    frequency synchronization
     selection input
     priority 10
     quality transmit exact itu-t option 1 ePRC
   
   ! Global frequency sync
   frequency synchronization
    quality itu-t option 1
    clock-interface timing-mode system
   ```

2. Verify commands:
   ```
   show frequency synchronization interfaces
   show frequency synchronization clock-interface
   show frequency synchronization selection
   ```

3. ESMC flow: when R3 (GPS source) sends SyncE to R4, R4's ESMC frame says "my quality = SSU-A (derived from PRC)". R5 receives ESMC from R4 and knows the quality before selecting it.

### Task 5: SyncE Protection (ESMC-Based Failover)

1. Scenario: R4 has TWO SyncE sources:
   - Primary: from R3 (QL = PRC)
   - Backup: from R6 (QL = SSU-A)
2. R4 selects R3 (better QL). If R3 fails:
   - R3's ESMC changes to QL-DNU (Do Not Use)
   - R4 detects via ESMC → switches to R6 (SSU-A)
   - R4's own ESMC downstream now advertises SSU-B (degraded)
3. When R3 recovers: wait-to-restore timer expires → R4 switches back to R3
4. Result: automatic, hitless frequency reference failover

---

## Section 3: PTP (IEEE 1588v2 — Precision Time Protocol)

### Task 6: Understand PTP Architecture

1. PTP provides both frequency AND phase/time synchronization
2. PTP operates at Layer 2 or Layer 3 (UDP port 319/320)
3. Clock types:

| Clock Type | Role | Where |
|---|---|---|
| Grandmaster (GM) | Source of time (typically GPS-connected) | R3 |
| Boundary Clock (BC) | Terminates and regenerates PTP | P routers (R4-R7) |
| Transparent Clock (TC) | Passes PTP through, corrects for residence time | Alternative to BC |
| Ordinary Clock (Slave) | Receives time, synchronizes local clock | PE routers, CEs |

4. PTP message flow:
   ```
   GM (R3) → Sync message (carries timestamp T1) → Slave (R8)
   Slave records arrival time T2
   Slave → Delay_Req → GM
   GM records arrival time T3, responds with Delay_Resp (T4)
   
   Offset = ((T2 - T1) - (T4 - T3)) / 2
   Delay  = ((T2 - T1) + (T4 - T3)) / 2
   ```

5. Result: slave knows EXACTLY how far off its clock is from the GM → corrects

### Task 7: PTP Profiles for SP Networks

1. **ITU-T G.8275.1 — Full Timing Support (Telecom Profile with Full Support from Network):**
   - Every node is a Boundary Clock
   - PTP runs on EVERY link hop-by-hop
   - Best accuracy: ±11 ns
   - Requires: ALL routers PTP-capable (expensive)

2. **ITU-T G.8275.2 — Partial Timing Support (Telecom Profile with Partial Support):**
   - NOT every node is PTP-aware
   - PTP traverses non-PTP nodes (transparent or just timestamps at ingress/egress)
   - Accuracy: ±1.5 μs (good enough for LTE-TDD)
   - More practical: can work over existing non-PTP network with just edge BCs

3. SP deployment strategy:
   - Core: SyncE (frequency) + PTP Boundary Clocks (phase)
   - Access: PTP slaves at cell sites
   - Hybrid: SyncE for frequency stability + PTP for phase alignment

### Task 8: PTP Configuration Reference

1. IOS-XR configuration (for exam reference):
   ```
   ! Configure PTP clock
   ptp
    clock
     domain 24
     profile g.8275.1 clock-type T-BC
    !
    profile TELECOM
     transport ethernet
     sync frequency 16
     announce frequency 8
     delay-request frequency 16
    !
    interface TenGigE0/0/0/0
     ptp
      profile TELECOM
      port state master
      transport ethernet
      multicast target-address non-forwardable
    !
    interface TenGigE0/0/0/1
     ptp
      profile TELECOM
      port state slave
   ```

2. Verify commands:
   ```
   show ptp clock
   show ptp foreign-masters
   show ptp interfaces
   show ptp platform servo
   ```

### Task 9: PTP + SyncE Hybrid Mode

1. Best practice for mobile backhaul: run BOTH SyncE and PTP simultaneously
2. **SyncE provides:** stable frequency reference (physical layer, not affected by packet delay variation)
3. **PTP provides:** phase/time-of-day alignment (packet-based, can cross non-SyncE links)
4. Hybrid benefit: PTP converges faster and more accurately when the underlying frequency is already synced by SyncE
5. Without SyncE: PTP must correct both frequency AND phase drift — slower, less accurate
6. With SyncE: PTP only corrects phase — faster convergence, better accuracy

---

## Section 4: Packet Delay Variation (PDV) and Timing Quality

### Task 10: Understand PDV Impact on PTP

1. PTP accuracy depends on symmetric network delay
2. If path delay from GM→Slave ≠ Slave→GM, PTP calculates wrong offset
3. Sources of PDV (Packet Delay Variation):
   - QoS queuing delays (different queue depths in each direction)
   - Load asymmetry (more traffic one way)
   - Different path lengths (asymmetric routing)
   - Store-and-forward vs cut-through switching

4. Mitigation strategies:
   - Use Boundary Clocks (terminate PTP per hop — eliminates accumulated PDV)
   - Prioritize PTP packets with highest QoS (DSCP 46/EF or 802.1p 7)
   - Use SyncE + PTP hybrid (frequency from SyncE, phase from PTP — reduces PTP's job)
   - On-path support: hardware timestamping at each hop

### Task 11: QoS for PTP Packets

1. PTP uses: UDP dst port 319 (event) and 320 (general)
2. Or: Ethernet multicast 01:80:C2:00:00:0E (forwardable) or 01:1B:19:00:00:00
3. Configure QoS to prioritize PTP:
   ```
   ip access-list extended PTP-TRAFFIC
    permit udp any any eq 319
    permit udp any any eq 320
   
   class-map match-any PTP
    match access-group name PTP-TRAFFIC
   
   policy-map TIMING-PRIORITY
    class PTP
     priority
    class class-default
     fair-queue
   
   interface GigabitEthernet1/0
    service-policy output TIMING-PRIORITY
   ```
4. Result: PTP packets never wait in queues → minimal PDV → better time accuracy

---

## Section 5: Mobile Backhaul Timing Design

### Task 12: End-to-End Timing Architecture for 5G

1. Document the full timing chain for a 5G mobile backhaul network:
   ```
   GNSS Antenna
       ↓
   Grandmaster Clock (at core site / data center)
       ↓ PTP + SyncE
   Core Router (Boundary Clock) — R3, R7
       ↓ PTP + SyncE
   Aggregation Router (Boundary Clock) — R5, R6, R13-R16
       ↓ PTP + SyncE
   Pre-Aggregation Router (Boundary Clock) — R2, R8, R17, R18
       ↓ PTP (last mile may not have SyncE)
   Cell Site Router / gNodeB (Ordinary Clock / Slave)
       ↓
   Radio Unit (needs ±130ns phase accuracy for 5G TDD)
   ```

2. Design considerations:
   - Max hops between GM and slave: 10-15 (each BC adds ~11ns error budget)
   - GPS backup: dual GM for redundancy (primary + secondary site)
   - Holdover: if ALL GPS sources fail, how long can the network maintain accuracy? (Depends on oscillator quality — typically hours to days for OCXO)

3. Timing budget (ITU-T G.8271.1):
   - Total budget from PRTC to end application: ±1.5 μs (LTE-TDD) or ±130 ns (5G)
   - Per BC: ~11 ns contribution
   - Network contribution: sum of all BCs + asymmetry + PDV
   - End application contribution: radio equipment internal delay

---

## CCIE+ Challenges

### Challenge 1: SyncE Ring Topology Protection

1. Design a SyncE ring with two GPS entry points
2. Document: how ESMC prevents timing loops in a ring
3. Implement: quality-level-based selection with QL-DNU for loop prevention
4. Test: fail primary GPS → verify seamless switchover to secondary GPS path

### Challenge 2: PTP Unicast vs Multicast

1. Document when to use:
   - **Multicast PTP:** small networks, all devices on same L2 segment
   - **Unicast PTP:** large networks, across L3 boundaries, telecom profile
2. Configure unicast negotiation between GM and slaves
3. Benefit: unicast scales better (no broadcast storms), works across routed networks

### Challenge 3: Asymmetry Compensation

1. Problem: fiber paths may have different lengths in each direction (different conduits)
2. This creates constant offset that PTP can't detect
3. Solution: configure static delay asymmetry compensation per interface:
   ```
   interface TenGigE0/0/0/0
    ptp
     delay-asymmetry 50 nanoseconds
   ```
4. Requires: physical measurement of fiber lengths in both directions
5. Result: PTP can achieve nanosecond accuracy even on asymmetric fiber plants

### Challenge 4: APTS (Assisted Partial Timing Support)

1. Concept: use existing non-PTP nodes as "transparent clocks" by adding timestamps
2. Even without full BC support, nodes timestamp PTP packets at ingress/egress
3. Allows PTP to work across a partially-upgraded network
4. Migration path: deploy APTS first, upgrade to full BCs gradually

---

## Final Validation

By the end of this lab, you understand:

- [ ] Why SPs need timing (mobile backhaul, financial, broadcast)
- [ ] Frequency vs Phase vs Time-of-Day synchronization
- [ ] SyncE: physical-layer frequency distribution, ESMC, quality levels
- [ ] PTP (1588v2): clock types (GM, BC, TC, OC), message exchange, offset calculation
- [ ] ITU-T profiles: G.8275.1 (full support) vs G.8275.2 (partial support)
- [ ] Hybrid SyncE + PTP: why both are needed together
- [ ] PDV impact and QoS mitigation for timing packets
- [ ] Mobile backhaul timing architecture (GNSS → GM → BC → Slave → Radio)
- [ ] Timing budget and accuracy requirements for 4G/5G
- [ ] (CCIE+) Ring protection, unicast PTP, asymmetry compensation, APTS
