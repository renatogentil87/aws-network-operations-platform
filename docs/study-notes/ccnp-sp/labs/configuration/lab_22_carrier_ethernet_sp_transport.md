# Lab 22: Carrier Ethernet & SP Transport — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — same physical topology
**Prerequisite:** Lab 1 complete (OSPF + LDP + MPLS), Lab 4 (AToM basics)

**End Goal:** Understand Carrier Ethernet standards (MEF), Ethernet OAM (802.1ag CFM, Y.1731), service types (E-Line, E-LAN, E-Tree), and how SPs monitor and maintain Ethernet services over MPLS. By the end, you understand the operational framework SPs use to sell, provision, and troubleshoot Ethernet services — the business side of L2VPN.

**Note:** Some features (Y.1731 performance monitoring, G.8032) may have limited support on IOS 15.2/7200. Where hardware support is lacking, configuration + conceptual understanding is documented for exam readiness.

---

## Topology Adaptation

No topology changes needed. Use the existing MPLS core with AToM/VPLS pseudowires from Labs 4/5/11:

```
E-Line Service (EPL): R1 ↔ R9 via EoMPLS pseudowire (R2↔R8)
E-LAN Service (EPLAN): R1, R9, R19, R20 via VPLS (R2, R8, R17, R18)
E-Tree Service: R12 (root) ↔ R11, R19 (leaves)

OAM Domain: spans R2 (MEP) → R3/R5 (MIPs) → R8 (MEP)
```

---

## Section 1: MEF Service Definitions

### Task 1: Understand MEF Ethernet Service Types

1. Document the three MEF service types and map to MPLS implementations:

| MEF Service | Description | MPLS Implementation | Your Lab |
|---|---|---|---|
| E-Line (EPL/EVPL) | Point-to-point | EoMPLS/AToM pseudowire | R1↔R9 |
| E-LAN (EP-LAN/EVP-LAN) | Multipoint-to-multipoint | VPLS | R1,R9,R19,R20 |
| E-Tree (EP-Tree) | Rooted multipoint (hub-spoke L2) | H-VPLS or EVPN | R12(root)↔R11,R19(leaf) |

2. Document MEF terminology:
   - UNI (User-Network Interface) = CE-PE interface
   - NNI (Network-Network Interface) = PE-PE or PE-P interface
   - EVC (Ethernet Virtual Connection) = the service instance
   - CE-VLAN ID = customer's VLAN
   - S-VLAN = SP's outer tag (QinQ)

3. No configuration needed — this is conceptual. Draw the service map for your topology.

### Task 2: Provision an E-Line Service

1. Configure EoMPLS between R2 and R8 (if not already from Lab 4):
   - R2 Fa0/0 `xconnect 8.8.8.8 100 encapsulation mpls`
   - R8 Gi1/0 `xconnect 2.2.2.2 100 encapsulation mpls`
2. Map to MEF: this pseudowire IS the EVC. Fa0/0 on R2 is UNI-A. Gi1/0 on R8 is UNI-B.
3. Verify: `show mpls l2transport vc 100` — EVC is UP
4. Verify: R1 can ping R9 (L2 connectivity across E-Line)
5. Document: this is an EPL (Ethernet Private Line) — port-based, dedicated bandwidth

### Task 3: Provision an E-LAN Service

1. Configure VPLS between R2, R8, R17, R18 (if not already from Lab 11):
   - VFI with VPN-ID 300, full-mesh neighbors
2. Map to MEF: this VPLS instance IS the EVC. Each CE-facing port is a UNI.
3. Verify: all four CEs can reach each other at L2 (same broadcast domain)
4. Document: this is an EP-LAN (Ethernet Private LAN) — multipoint, all-to-all

---

## Section 2: Ethernet OAM — CFM (802.1ag)

### Task 4: Understand CFM Architecture

1. Document the CFM hierarchy:
   - **MD (Maintenance Domain):** defines the scope of OAM (e.g., customer, provider, operator)
   - **MA (Maintenance Association):** a specific service within an MD (maps to one EVC)
   - **MEP (Maintenance Endpoint):** source/sink of OAM frames — on PE at service edge
   - **MIP (Maintenance Intermediate Point):** on P routers — responds to but doesn't generate OAM
   - **MD Level (0-7):** customer=7, provider=4, operator=1 (higher can see lower, not vice versa)

2. Map to your topology:
   ```
   MD Level 4 (Provider): spans R2(MEP) → core → R8(MEP)
   MD Level 7 (Customer): spans R1(MEP) → R2 → core → R8 → R9(MEP)
   MIPs: R3, R5 (P routers on the path)
   ```

### Task 5: Configure CFM on PE Routers

1. On R2: configure Ethernet CFM:
   ```
   ethernet cfm domain PROVIDER level 4
    service E-LINE-100 evc EVC-100
     continuity-check
     continuity-check interval 1s
   
   interface FastEthernet0/0
    ethernet cfm mep domain PROVIDER mpid 1 service E-LINE-100
   ```
2. On R8: configure matching CFM:
   ```
   ethernet cfm domain PROVIDER level 4
    service E-LINE-100 evc EVC-100
     continuity-check
   
   interface GigabitEthernet1/0
    ethernet cfm mep domain PROVIDER mpid 2 service E-LINE-100
   ```
3. Verify: `show ethernet cfm maintenance-points` — MEPs listed
4. Verify: `show ethernet cfm errors` — no errors (CCM exchange healthy)

### Task 6: CCM (Continuity Check Messages)

1. CCM = heartbeat between MEPs (like OSPF hello for Ethernet OAM)
2. MEPs exchange CCMs at configured interval (1s, 10s, 1min, 10min)
3. If 3.5× interval passes without receiving CCM from remote MEP → fault declared
4. Verify: `show ethernet cfm maintenance-points remote` — shows remote MEP with status "OK"
5. Test: shut the pseudowire (break the EVC) → observe: remote MEP status changes to "Timeout"
6. Restore → status returns to "OK"
7. Use case: SP monitors EVC health without pinging customer IPs

### Task 7: CFM Loopback and Linktrace

1. **Loopback (LBM/LBR):** like ping for Ethernet OAM
   - `ping ethernet mpid 2 domain PROVIDER service E-LINE-100`
   - Sends Loopback Message (LBM) to remote MEP, expects Loopback Reply (LBR)
   - Verify: replies received = connectivity confirmed at L2

2. **Linktrace (LTM/LTR):** like traceroute for Ethernet OAM
   - `traceroute ethernet mpid 2 domain PROVIDER service E-LINE-100`
   - LTM follows the path, each MIP/MEP responds with LTR
   - Shows each L2 hop between the two MEPs
   - Use case: identify WHERE in the path a fault exists

---

## Section 3: Y.1731 Performance Monitoring

### Task 8: Understand Y.1731 Measurements

1. Y.1731 extends CFM with performance metrics:
   - **Frame Delay (two-way):** round-trip time between MEPs
   - **Frame Delay Variation (jitter):** variation in delay
   - **Frame Loss:** percentage of frames lost between MEPs
   - **Throughput:** maximum achievable bandwidth

2. These metrics map to MEF SLA parameters:
   - Frame Delay < 10ms (metro), < 50ms (national)
   - Frame Loss < 0.01%
   - Availability > 99.99%

3. Configure (if supported on your IOS):
   ```
   ethernet cfm domain PROVIDER level 4
    service E-LINE-100 evc EVC-100
     continuity-check
   
   ip sla 1
    ethernet y1731 delay dmm domain PROVIDER evc EVC-100 mpid 2 cos 5
     frequency 60
   ip sla schedule 1 start-time now life forever
   ```
4. Verify: `show ip sla statistics 1` — shows delay measurements
5. If not supported: document the concept and configuration for exam purposes

### Task 9: Synthetic SLA Monitoring with IP SLA

1. Alternative to Y.1731 — use IP SLA for Ethernet service monitoring:
   ```
   ip sla 10
    icmp-echo 10.0.0.2 source-ip 10.0.0.1
     frequency 10
     threshold 100
   ip sla schedule 10 start-time now life forever
   
   ip sla reaction-configuration 10 react timeout threshold-type immediate action-type trapOnly
   ```
2. Verify: `show ip sla statistics` — RTT measurements
3. Configure: `track 1 ip sla 10 reachability` — track the SLA for failover triggers
4. Use case: when Y.1731 isn't available, IP SLA provides per-service monitoring

---

## Section 4: EFP (Ethernet Flow Point)

### Task 10: Configure EFP for Service Multiplexing

1. EFP = flexible match for Ethernet frames on a trunk interface (replacement for sub-interfaces):
   ```
   interface GigabitEthernet1/0
    service instance 100 ethernet
     encapsulation dot1q 100
     rewrite ingress tag pop 1 symmetric
     xconnect 8.8.8.8 100 encapsulation mpls
    !
    service instance 200 ethernet
     encapsulation dot1q 200
     rewrite ingress tag pop 1 symmetric
     xconnect 17.17.17.17 200 encapsulation mpls
   ```
2. Each `service instance` = one EFP = one EVC on the same physical port
3. `encapsulation dot1q 100` = match customer VLAN 100
4. `rewrite ingress tag pop 1` = remove VLAN tag before sending into PW
5. Verify: `show ethernet service instance` — lists all EFPs and their state
6. Benefit over sub-interfaces: more flexible matching (double-tag, untagged, range of VLANs)

### Task 11: EFP with QinQ

1. Configure EFP that matches double-tagged frames:
   ```
   service instance 300 ethernet
    encapsulation dot1q 500 second-dot1q 100
    rewrite ingress tag pop 2 symmetric
    xconnect 8.8.8.8 300 encapsulation mpls
   ```
2. Matches: outer S-tag 500, inner C-tag 100
3. Pops both tags before entering pseudowire
4. Remote PE pushes both tags back (symmetric rewrite)
5. Use case: wholesale service — match specific customer within a provider VLAN

---

## Section 5: Ethernet Ring Protection (G.8032/ERPS)

### Task 12: Understand G.8032 Concepts

1. G.8032 = Ethernet Ring Protection Switching — sub-50ms L2 failover for ring topologies
2. Components:
   - **Ring:** physical Ethernet ring between switches/PEs
   - **RPL (Ring Protection Link):** one link blocked in normal state (prevents loop)
   - **RPL Owner:** the node that blocks the RPL
   - **R-APS:** Ring Automatic Protection Switching (OAM messages on ring)
3. Failure: link fails → R-APS signal sent → RPL owner unblocks RPL → traffic reroutes in <50ms
4. Recovery: failed link restores → R-APS signal → RPL owner re-blocks RPL → traffic returns

5. Map to your topology (conceptual — simulate a ring):
   ```
   R2 ── R3 ── R7 ── R8
   |                    |
   └──── R6 ──── R5 ──┘
   
   RPL: R2↔R6 link (blocked in normal state)
   ```

6. Configuration (if supported):
   ```
   ethernet ring g8032 RING1
    port0 interface GigabitEthernet1/0
    port1 interface GigabitEthernet2/0
    instance 1
     profile RING-PROFILE
     rpl port0 owner
   ```
7. Note: G.8032 requires specific IOS images and hardware. Document for exam purposes.

---

## Section 6: Carrier Ethernet Design Principles

### Task 13: Service Bandwidth Profiles (MEF)

1. Document MEF bandwidth profile parameters:
   - **CIR (Committed Information Rate):** guaranteed minimum bandwidth
   - **CBS (Committed Burst Size):** burst allowance at CIR
   - **EIR (Excess Information Rate):** best-effort additional bandwidth
   - **EBS (Excess Burst Size):** burst allowance at EIR
   - Frames within CIR → marked Green (forwarded always)
   - Frames between CIR and EIR → marked Yellow (forwarded if capacity available)
   - Frames above EIR → marked Red (dropped)

2. Implement with QoS policing on UNI:
   ```
   policy-map BANDWIDTH-PROFILE
    class class-default
     police cir 10000000 bc 312500 pir 20000000 be 312500
      conform-action transmit
      exceed-action set-dscp-transmit af11
      violate-action drop
   
   interface FastEthernet0/0
    service-policy input BANDWIDTH-PROFILE
   ```
3. Verify: `show policy-map interface Fa0/0` — see conform/exceed/violate counters
4. This implements the MEF bandwidth profile as an ingress policer at the UNI

### Task 14: CoS Preservation Across the MPLS Core

1. Customer sends frames with 802.1p CoS values (0-7) at the UNI
2. PE must preserve CoS end-to-end (map 802.1p → MPLS EXP → 802.1p at egress)
3. Configure CoS-to-EXP mapping:
   ```
   policy-map COS-TO-EXP
    class cos-5
     set mpls experimental topmost 5
    class cos-0
     set mpls experimental topmost 0
   ```
4. At egress PE: map EXP back to CoS on egress frame
5. Verify: end-to-end CoS preserved for customer's voice/video traffic
6. This is how SPs deliver multi-CoS Ethernet services over a shared MPLS backbone

---

## CCIE+ Challenges

### Challenge 1: Multi-Domain CFM (Nested OAM)

1. Configure THREE CFM domains:
   - Level 1: Operator (PE-to-PE core monitoring)
   - Level 4: Provider (UNI-to-UNI service monitoring)
   - Level 7: Customer (CE-to-CE end-user monitoring)
2. Each level can only see its own and lower levels
3. Verify: customer CFM can detect end-to-end faults; provider CFM narrows to SP network

### Challenge 2: E-Tree Service with VPLS

1. Implement E-Tree using VPLS with split-horizon modifications:
   - Root sites (R12) can communicate with ALL leaves
   - Leaf sites (R11, R19) can communicate with root but NOT with each other
2. Implementation: use VPLS with selective PW blocking between leaf PEs
3. Verify: R12↔R11 works, R12↔R19 works, R11↔R19 blocked

### Challenge 3: Ethernet LMI (E-LMI)

1. Configure E-LMI between PE and CE:
   ```
   interface FastEthernet0/0
    ethernet lmi interface
   ```
2. E-LMI provides CE with service status (EVC UP/DOWN) without running CFM on CE
3. CE auto-discovers available EVCs and their status from the PE
4. Use case: zero-touch CE provisioning — CE learns what services are available

### Challenge 4: PBB-EVPN (Provider Backbone Bridging with EVPN)

1. Concept: MAC-in-MAC encapsulation with EVPN control plane
2. Customer frames get a provider backbone MAC header (B-MAC)
3. Scales to millions of customer MACs without SP learning them all
4. Document architecture: how PBB hides customer MACs from the backbone

---

## Final Validation

By the end of this lab, your network has:

- [ ] MEF service types understood and mapped to MPLS implementations
- [ ] E-Line (EPL) provisioned with EoMPLS
- [ ] E-LAN (EP-LAN) provisioned with VPLS
- [ ] CFM configured with MEPs exchanging CCMs
- [ ] CFM Loopback and Linktrace for fault isolation
- [ ] Y.1731 or IP SLA for service performance monitoring
- [ ] EFP for flexible service multiplexing on trunk interfaces
- [ ] MEF bandwidth profiles implemented with QoS policing
- [ ] CoS preservation across MPLS (802.1p → EXP → 802.1p)
- [ ] (CCIE+) Multi-domain CFM, E-Tree, E-LMI, PBB-EVPN concepts
