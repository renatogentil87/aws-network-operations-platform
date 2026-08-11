# Lab 28: L2VPN Interworking — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 2 RRs, 6 CEs. Full MPLS core with LDP operational.
**Prerequisite:** Labs 4 and 5 complete (AToM pseudowires working, tunnel selection understood)

**End Goal:** Connect customer sites using different Layer 2 encapsulations — Ethernet-to-Ethernet with VLAN tag rewriting, Frame Relay-to-Ethernet (IP interworking), HDLC-to-Ethernet, L2TPv3 as alternative transport, local switching (hairpin pseudowires on same PE), and multi-segment pseudowire stitching across intermediate PEs. By the end, you can bridge ANY Layer 2 technology combination the customer throws at you.

---

## Section 1: Ethernet-to-Ethernet VLAN Interworking (Tag Rewrite)

### Task 1: Basic Ethernet Pseudowire with VLAN Match

1. On R2 (PE, toward R1 CE): configure attachment circuit matching VLAN 100:
   ```
   interface GigabitEthernet1/0.100
    encapsulation dot1Q 100
    xconnect 8.8.8.8 1001 encapsulation mpls
   ```
2. On R8 (PE, toward R9 CE): configure matching pseudowire with VLAN 200:
   ```
   interface GigabitEthernet1/0.200
    encapsulation dot1Q 200
    xconnect 2.2.2.2 1001 encapsulation mpls
   ```
3. R1 sends on VLAN 100 → R9 receives on VLAN 200 (VLAN translation)
4. Verify: `show xconnect all` — pseudowire UP, attachment circuits UP
5. Verify: `show mpls l2transport vc 1001` — Local: Eth VLAN 100, Remote: Eth VLAN 200
6. On R1: `ping 10.0.0.9 source 10.0.0.1` (assuming L3 in same subnet on the VLAN interfaces)
7. **Key concept:** the pseudowire strips the VLAN tag at ingress PE, transports Ethernet frame, egress PE adds its own VLAN tag

### Task 2: VLAN Tag Rewrite Modes

1. **Mode 1 — Tag removal (pop):**
   ```
   interface GigabitEthernet1/0.100
    encapsulation dot1Q 100
    rewrite ingress tag pop 1 symmetric
   ```
   - Ingress: removes outer VLAN tag before sending into pseudowire
   - Egress: adds VLAN tag when frame exits pseudowire
2. **Mode 2 — Tag translation (translate):**
   ```
   interface GigabitEthernet1/0.100
    encapsulation dot1Q 100
    rewrite ingress tag translate 1-to-1 dot1q 300 symmetric
   ```
   - Translates VLAN 100 → VLAN 300 at ingress
3. **Mode 3 — Tag push (QinQ):**
   ```
   interface GigabitEthernet1/0.100
    encapsulation dot1Q 100 second-dot1q 500
    rewrite ingress tag push dot1q 200 symmetric
   ```
4. Verify each mode: capture frames on pseudowire — inspect VLAN tags
5. Verify: `show ethernet service instance detail` — rewrite counters
6. **SP use case:** customer uses VLAN 100 at Site A, VLAN 200 at Site B — SP handles translation transparently

### Task 3: Port-Based vs VLAN-Based Attachment Circuit

1. **Port-based (all traffic on interface goes into pseudowire):**
   ```
   interface GigabitEthernet2/0
    xconnect 8.8.8.8 1002 encapsulation mpls
   ```
   - All frames regardless of VLAN go into this pseudowire
2. **VLAN-based (specific VLAN → specific pseudowire):**
   ```
   interface GigabitEthernet2/0.100
    encapsulation dot1Q 100
    xconnect 8.8.8.8 1003 encapsulation mpls
   interface GigabitEthernet2/0.200
    encapsulation dot1Q 200
    xconnect 17.17.17.17 1004 encapsulation mpls
   ```
   - VLAN 100 → pseudowire to R8, VLAN 200 → pseudowire to R17
3. Verify: `show xconnect all` — multiple pseudowires from same physical interface
4. Verify: traffic on VLAN 100 arrives at R8, VLAN 200 arrives at R17
5. **Scalability:** single interface can carry dozens of pseudowires (one per VLAN)
6. Test: send tagged traffic on wrong VLAN — verify it does NOT enter the pseudowire

---

## Section 2: Frame Relay-to-Ethernet Interworking

### Task 4: FR-to-Ethernet IP Interworking Mode

1. **Scenario:** R11 (CE) connects via Frame Relay, R12 (CE) connects via Ethernet
2. On R17 (PE, toward R11): configure Frame Relay attachment circuit:
   ```
   interface Serial2/0
    encapsulation frame-relay
    frame-relay intf-type dce
   !
   connect FR-TO-ETH Serial2/0 100 l2transport
    xconnect 18.18.18.18 2001 encapsulation mpls
     interworking ip
   ```
3. On R18 (PE, toward R12): configure Ethernet attachment circuit:
   ```
   interface GigabitEthernet1/0
    xconnect 17.17.17.17 2001 encapsulation mpls
     interworking ip
   ```
4. **IP Interworking mode:** L2 headers stripped, only IP payload transported
   - Ingress (R17): strips FR header, encapsulates IP in pseudowire
   - Egress (R18): adds Ethernet header (destination MAC from ARP/config)
5. Verify: `show mpls l2transport vc 2001 detail` — interworking type: IP
6. Verify: `ping` from R11 to R12 across the interworked pseudowire
7. **Limitation:** only IP traffic works in IP interworking mode — non-IP protocols dropped

### Task 5: FR-to-Ethernet Ethernet Interworking Mode

1. **Ethernet interworking mode:** preserves Ethernet frames end-to-end
2. On R17 (FR side): cannot use Ethernet interworking directly (FR has no Ethernet header)
3. **Solution:** use "bridged" encapsulation on FR:
   ```
   interface Serial2/0.100 point-to-point
    frame-relay interface-dlci 100
    frame-relay payload-compress bridged
   !
   connect FR-BRIDGE Serial2/0.100 l2transport
    xconnect 18.18.18.18 2002 encapsulation mpls
     interworking ethernet
   ```
4. On R18: Ethernet attachment circuit with interworking ethernet
5. Verify: `show mpls l2transport vc 2002 detail` — interworking type: Ethernet
6. **Caveat:** bridged interworking requires the FR CPE to support RFC 2427 bridged format
7. If FR CPE doesn't support bridged: fall back to IP interworking (Task 4)
8. Document: when to use IP vs Ethernet interworking mode

### Task 6: DLCI-to-VLAN Mapping

1. Multiple DLCIs on FR side mapping to different VLANs on Ethernet side:
   - DLCI 100 ↔ VLAN 100 (pseudowire VC 2010)
   - DLCI 200 ↔ VLAN 200 (pseudowire VC 2020)
   - DLCI 300 ↔ VLAN 300 (pseudowire VC 2030)
2. On R17 (FR PE):
   ```
   connect DLCI100 Serial2/0 100 l2transport
    xconnect 18.18.18.18 2010 encapsulation mpls
     interworking ip
   connect DLCI200 Serial2/0 200 l2transport
    xconnect 18.18.18.18 2020 encapsulation mpls
     interworking ip
   ```
3. On R18 (Ethernet PE): separate sub-interfaces per VLAN
4. Verify: `show xconnect all` — three pseudowires, each mapping DLCI→VLAN
5. Verify: traffic on DLCI 100 arrives on VLAN 100, DLCI 200 on VLAN 200
6. **SP use case:** migrating FR customer to Ethernet — one DLCI at a time

---

## Section 3: HDLC-to-Ethernet Interworking

### Task 7: HDLC Attachment Circuit

1. On R17 (PE): configure HDLC interface toward R11:
   ```
   interface Serial3/0
    encapsulation hdlc
    xconnect 18.18.18.18 3001 encapsulation mpls
     interworking ip
   ```
2. On R18 (PE, Ethernet side toward R12):
   ```
   interface GigabitEthernet2/0
    xconnect 17.17.17.17 3001 encapsulation mpls
     interworking ip
   ```
3. **IP interworking:** strips HDLC header at R17, adds Ethernet header at R18
4. Verify: `show mpls l2transport vc 3001` — Local: HDLC, Remote: Ethernet
5. Verify: `ping` from R11 (HDLC) to R12 (Ethernet) — connectivity works
6. Verify: `show mpls l2transport vc 3001 detail` — packet counters incrementing
7. **Limitation:** HDLC is point-to-point — only one pseudowire per serial interface

### Task 8: PPP-to-Ethernet Interworking

1. On R17: change serial encapsulation to PPP:
   ```
   interface Serial3/0
    encapsulation ppp
    xconnect 18.18.18.18 3002 encapsulation mpls
     interworking ip
   ```
2. Verify: PPP negotiation completes (LCP/IPCP)
3. Verify: pseudowire UP with IP interworking
4. `show mpls l2transport vc 3002` — Local: PPP, Remote: Ethernet
5. Ping from R11 (PPP) to R12 (Ethernet) — works via IP interworking
6. **Key point:** IP interworking is the universal glue — strips ANY L2 header, transports IP
7. Document: which L2 combinations support Ethernet interworking vs IP-only interworking

---

## Section 4: L2TPv3 as Alternative to AToM

### Task 9: L2TPv3 Pseudowire (IP-Based Transport)

1. **L2TPv3 vs AToM:** L2TPv3 runs over IP (no MPLS needed), AToM requires MPLS core
2. On R2: configure L2TPv3 pseudowire class:
   ```
   pseudowire-class L2TPv3-PW
    encapsulation l2tpv3
    ip local interface Loopback0
   ```
3. On R2: configure xconnect using L2TPv3:
   ```
   interface GigabitEthernet3/0
    xconnect 8.8.8.8 4001 pw-class L2TPv3-PW
   ```
4. On R8: matching configuration:
   ```
   pseudowire-class L2TPv3-PW
    encapsulation l2tpv3
    ip local interface Loopback0
   !
   interface GigabitEthernet3/0
    xconnect 2.2.2.2 4001 pw-class L2TPv3-PW
   ```
5. Verify: `show xconnect all` — L2TPv3 pseudowire UP
6. Verify: `show l2tun session all` — L2TPv3 session details
7. Verify: ping between CEs across L2TPv3 pseudowire
8. **Use case:** L2VPN over IP-only core (no MPLS), or L2VPN over the internet (with IPsec)

### Task 10: L2TPv3 with Cookie and Sequencing

1. Add session cookie for security:
   ```
   pseudowire-class L2TPv3-SECURE
    encapsulation l2tpv3
    ip local interface Loopback0
    l2tp cookie size 8
    sequencing both
   ```
2. Verify: `show l2tun session detail` — cookie value and sequencing enabled
3. **Cookie:** prevents pseudowire hijacking — remote PE must present correct cookie
4. **Sequencing:** detects packet reordering (useful over IP networks with ECMP)
5. Test: misconfigure cookie on one side — verify pseudowire fails to establish
6. Fix cookie — verify pseudowire recovers
7. Compare performance: L2TPv3 (IP encap, ~20 byte overhead) vs AToM (MPLS, ~8 byte overhead)

### Task 11: L2TPv3 over IPv6

1. Configure L2TPv3 using IPv6 transport:
   ```
   pseudowire-class L2TPv3-IPV6
    encapsulation l2tpv3
    ip local interface Loopback0
    ip protocol l2tpv3
   ```
   (Use IPv6 addresses on Loopback0 if available)
2. Verify: L2TPv3 session over IPv6 underlay
3. **Use case:** SP migrating to IPv6 core but still carrying IPv4 L2 services
4. Verify: `show l2tun session` — session uses IPv6 transport addresses
5. Document: L2TPv3 advantages (IP transport, IPsec integration, no MPLS dependency) vs disadvantages (larger overhead, less mature in SP networks)

---

## Section 5: Local Switching (Same-PE Pseudowire)

### Task 12: Local Switching — Hairpin on Same PE

1. **Scenario:** two customer interfaces on the SAME PE need L2 connectivity
2. On R2: configure local switching (no remote PE, no pseudowire label):
   ```
   connect LOCAL-SWITCH GigabitEthernet1/0.100 GigabitEthernet2/0.200
   ```
   Or using xconnect with local keyword:
   ```
   interface GigabitEthernet1/0.100
    encapsulation dot1Q 100
    xconnect local GigabitEthernet2/0.200
   ```
3. Verify: `show connection all` — local switching active
4. Verify: frames entering Gi1/0.100 exit on Gi2/0.200 (and vice versa)
5. Ping between devices connected to both interfaces — works as direct L2 bridge
6. **Use case:** connect two ports on same PE without using a VLAN bridge — more efficient
7. Verify: `show mpls l2transport vc` — no pseudowire VC ID for local switching (it's purely local)

### Task 13: Local Switching with VLAN Translation

1. Configure local switching between different VLANs on same PE:
   ```
   connect VLAN-XLATE GigabitEthernet1/0.100 GigabitEthernet1/0.300
   ```
   - VLAN 100 traffic ↔ VLAN 300 traffic (same physical interface, different sub-interfaces)
2. Verify: host on VLAN 100 can communicate with host on VLAN 300
3. **Use case:** customer migration — transition traffic from old VLAN to new VLAN without touching CE
4. Verify: `show connection all detail` — counters for both directions
5. Test: send broadcast on VLAN 100 — verify it appears on VLAN 300
6. Remove local connection: `no connect VLAN-XLATE`

---

## Section 6: Multi-Segment Pseudowire Stitching

### Task 14: Two-Segment Pseudowire (S-PE)

1. **Scenario:** R2 and R18 cannot establish direct pseudowire (different IGP domains, no direct LSP)
2. Use R8 as Switching PE (S-PE) — stitches two pseudowire segments:
3. On R2 (T-PE1): pseudowire to R8 (S-PE):
   ```
   interface GigabitEthernet1/0.500
    encapsulation dot1Q 500
    xconnect 8.8.8.8 5001 encapsulation mpls
   ```
4. On R8 (S-PE): stitch the two segments:
   ```
   l2 vfi PW-STITCH manual
    vpn id 5001
    neighbor 2.2.2.2 pw-id 5001 encapsulation mpls
    neighbor 18.18.18.18 pw-id 5002 encapsulation mpls
   ```
   Or using pseudowire switching:
   ```
   interface pseudowire1
    encapsulation mpls
    neighbor 2.2.2.2 5001
   interface pseudowire2
    encapsulation mpls
    neighbor 18.18.18.18 5002
   !
   l2vpn xconnect context PW-STITCH
    member pseudowire1
    member pseudowire2
   ```
5. On R18 (T-PE2): pseudowire to R8:
   ```
   interface GigabitEthernet1/0.500
    encapsulation dot1Q 500
    xconnect 8.8.8.8 5002 encapsulation mpls
   ```
6. Verify: `show xconnect all` on R8 — two pseudowire segments stitched
7. Verify: traffic from R2's CE reaches R18's CE (end-to-end through S-PE)
8. Verify: `show mpls l2transport vc` on R8 — both VC 5001 and 5002 UP

### Task 15: Multi-Segment PW with Control Word

1. Enable control word on all segments (MUST match end-to-end):
   ```
   pseudowire-class PW-WITH-CW
    encapsulation mpls
    control-word
   ```
2. Apply to both pseudowire segments
3. Verify: `show mpls l2transport vc detail` — "control word enabled" on all segments
4. **Why control word matters:** prevents ECMP load-balancing from reordering L2 frames
5. Test: disable control word on one segment, enable on other → pseudowire fails
6. Fix: ensure control word matches on both ends of each segment
7. **Multi-segment rule:** control word setting must be consistent across ALL segments

### Task 16: Three-Segment Pseudowire

1. Build a three-segment pseudowire: R2 → R5 (S-PE1) → R7 (S-PE2) → R18
2. On R5: stitch segments 1 and 2 (R2→R5, R5→R7)
3. On R7: stitch segments 2 and 3 (R5→R7, R7→R18)
4. Verify: `show xconnect all` on R5 and R7 — each shows stitched segments
5. Verify: end-to-end connectivity from R2's CE to R18's CE
6. Verify: `show mpls l2transport vc` — three separate VC IDs (one per segment)
7. **Use case:** inter-provider L2VPN (each provider manages their own pseudowire segment)
8. Measure: latency through three-segment PW vs direct PW (additional S-PE processing overhead)

---

## CCIE+ Challenges

### Challenge 1: Pseudowire Redundancy with Backup PW

1. Configure primary pseudowire R2↔R8 (VC 6001) and backup R2↔R17 (VC 6002):
   ```
   interface GigabitEthernet1/0.600
    xconnect 8.8.8.8 6001 encapsulation mpls
     backup peer 17.17.17.17 6002
     backup delay 0 0
   ```
2. Verify: `show xconnect all` — primary active, backup standby
3. Shut R8's pseudowire interface — verify failover to backup (R17)
4. Bring R8 back — verify reversion to primary (if configured)
5. Configure `no backup delay` — prevent immediate reversion (hold on backup until manual switchback)
6. **SP use case:** resilient L2VPN service with automatic failover

### Challenge 2: L2VPN Interworking with QoS

1. Configure QoS on pseudowire:
   ```
   pseudowire-class QOS-PW
    encapsulation mpls
    mpls experimental 5
   ```
2. Map customer CoS (802.1p) to MPLS EXP for pseudowire:
   - COS 5 → EXP 5 (voice)
   - COS 0 → EXP 0 (best effort)
3. Verify: `show policy-map interface` on pseudowire — QoS applied
4. Verify: traffic with COS 5 gets EXP 5 label marking through the core
5. **End-to-end:** customer VLAN priority → MPLS EXP → customer VLAN priority (preserved)

### Challenge 3: Interworking with MTU Mismatch Handling

1. **Problem:** FR MTU = 1500, Ethernet MTU = 1500, but MPLS adds overhead
2. Configure MTU on pseudowire: `mtu 1500`
3. Test with 1500-byte frames — verify fragmentation behavior
4. On AToM: `mpls l2transport mtu` sets the MTU advertised to remote PE
5. Mismatch: configure 1500 on one side, 1400 on other → pseudowire fails (MTU mismatch)
6. Fix: align MTU on both PEs
7. Enable MPLS fragmentation if needed: `mpls mtu 1530` on core interfaces
8. **Best practice:** set core MTU to at least 1530 (1500 + MPLS labels + L2 header overhead)

### Challenge 4: AToM with Any Transport over MPLS (Cisco HDLC, PPP, ATM)

1. Configure ATM-to-Ethernet interworking (if ATM interfaces available):
   ```
   interface ATM2/0.1
    pvc 1/100 l2transport
     encapsulation aal5snap
     xconnect 8.8.8.8 7001 encapsulation mpls
      interworking ip
   ```
2. Map ATM VPI/VCI to Ethernet pseudowire
3. Verify: `show atm vc` — ATM VC active and bound to pseudowire
4. If no ATM hardware: document the configuration and explain VPI/VCI-to-pseudowire mapping
5. **Complete interworking matrix:** document which L2 types can interwork with which

---

## Final Validation

By the end of this lab, your network has:

- [ ] Ethernet-to-Ethernet pseudowire with VLAN tag rewrite (pop, translate, push)
- [ ] Port-based and VLAN-based attachment circuits on same physical interface
- [ ] Frame Relay-to-Ethernet working via IP interworking mode
- [ ] Multiple DLCI-to-VLAN mappings on single FR interface
- [ ] HDLC-to-Ethernet interworking via IP mode
- [ ] PPP-to-Ethernet interworking via IP mode
- [ ] L2TPv3 pseudowire operational (IP transport, no MPLS required)
- [ ] L2TPv3 with cookie security and sequencing
- [ ] Local switching (hairpin) between interfaces on same PE
- [ ] Local switching with VLAN translation
- [ ] Two-segment multi-segment pseudowire through S-PE (R8)
- [ ] Three-segment pseudowire through two S-PEs (R5, R7)
- [ ] Control word consistency enforced across segments
- [ ] (CCIE+) Pseudowire redundancy with backup PW and failover
- [ ] (CCIE+) QoS mapping from customer CoS to MPLS EXP on pseudowire
- [ ] (CCIE+) MTU handling documented for interworking scenarios
