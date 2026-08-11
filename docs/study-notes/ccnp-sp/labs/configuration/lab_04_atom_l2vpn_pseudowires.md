# Lab 4: AToM — L2VPN Pseudowires Over MPLS — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs (R2, R8, R17, R18), 9 P routers. Focus on PE-to-PE L2 circuits.
**Prerequisite:** Lab 1 complete (OSPF + LDP running, all loopbacks reachable via MPLS)

**End Goal:** A working L2VPN service where customer Ethernet frames traverse the MPLS core transparently — the customer sees a "virtual wire" between two sites. By the end, you have multiple pseudowires carrying different L2 services, with OAM verification proving the circuits are healthy. This is how SPs sell Ethernet Private Line (EPL) and Virtual Private Wire Service (VPWS).

---

## Section 1: First Pseudowire — Ethernet over MPLS (EoMPLS)

### Task 1: Simple Point-to-Point Pseudowire (R2 ↔ R8) - DONE

1. On R2: configure `xconnect` on Fa0/0 (the interface toward R1):
   - `interface FastEthernet0/0`
   - `xconnect 8.8.8.8 100 encapsulation mpls` (VC ID 100, peer = R8 loopback)
2. On R8: configure `xconnect` on Gi1/0 (the interface toward R9):
   - `interface GigabitEthernet1/0`
   - `xconnect 2.2.2.2 100 encapsulation mpls` (VC ID 100, peer = R2 loopback)
3. **Important:** remove any IP address and VRF config from these interfaces first — they become pure L2 ports
4. On R1: configure an IP address on Fa0/0 (e.g., 10.0.0.1/24)
5. On R9: configure an IP address on Gi1/0 (e.g., 10.0.0.2/24) — same subnet as R1
6. Verify: `show mpls l2transport vc 100` on R2 — status should be UP
7. Verify: `show mpls l2transport vc 100` on R8 — status should be UP
8. Verify: R1 can ping R9 (10.0.0.2) — L2 frame crosses the MPLS core transparently
9. On R1: `show arp` — R9's MAC address should be learned directly (as if they're on the same LAN)

### Task 2: Understand the Label Stack - DONE

1. From R1: `traceroute 10.0.0.2` — observe the hops
2. On R2: `show mpls l2transport vc 100 detail` — note the VC label (imposed by R2) and the transport label (to reach 8.8.8.8)
3. On R2: `show mpls forwarding-table` — find the entry for the VC label
4. The label stack is: **transport label (top)** + **VC label (bottom)**
   - Transport label: gets the packet to R8 (same as any LDP label to 8.8.8.8)
   - VC label: tells R8 which pseudowire this belongs to (which local interface to send out)
5. On R3 (P router): `show mpls forwarding-table` — P routers only swap the transport label (never see the VC label)
6. Compare with L3VPN: L3VPN uses transport + VPN label. AToM uses transport + VC label. Same two-label concept.

### Task 3: Verify L2 Transparency - DONE

1. On R1: change IP to something completely different (e.g., 172.16.99.1/24)
2. On R9: change IP to 172.16.99.2/24
3. Verify: R1 can still ping R9 — the pseudowire doesn't care about IP; it carries ANY L2 frame
4. On R1: send a broadcast ping — `ping 172.16.99.255`
5. On R9: check — did R9 receive the broadcast? (It should — it's a L2 circuit)
6. **Key insight:** the PE doesn't inspect or route the customer traffic. It just encapsulates the Ethernet frame in MPLS and sends it to the remote PE.

---

## Section 2: Multiple Pseudowires — Scale the L2VPN Service

### Task 4: Second Pseudowire — Different Customers - DONE

1. On R2: configure `xconnect` on Fa3/0 (toward R12):
   - `xconnect 8.8.8.8 200 encapsulation mpls` (VC ID 200 — different customer)
2. On R8: configure `xconnect` on Fa4/0 (toward R11):
   - `xconnect 2.2.2.2 200 encapsulation mpls` (VC ID 200)
3. Remove IP/VRF config from those interfaces — make them pure L2
4. On R12: configure IP 10.1.0.1/24 on its interface toward R2
5. On R11: configure IP 10.1.0.2/24 on its interface toward R8
6. Verify: `show mpls l2transport vc` on R2 — both VC 100 and VC 200 show UP
7. Verify: R12 can ping R11 (10.1.0.2) — second pseudowire works
8. Verify: R12 CANNOT ping R1 (different pseudowire = complete isolation)
9. Verify: R1 CANNOT ping R11 (different pseudowire)

### Task 5: Pseudowire Between Different PE Pairs 0 DONE

1. On R17: configure `xconnect` on Fa3/0 (toward R19):
   - `xconnect 18.18.18.18 300 encapsulation mpls` (VC ID 300, peer = R18)
2. On R18: configure `xconnect` on Gi2/0 (toward R20):
   - `xconnect 17.17.17.17 300 encapsulation mpls` (VC ID 300)
3. Remove IP/VRF config from those interfaces
4. On R19: configure IP 10.2.0.1/24 on Fa3/0
5. On R20: configure IP 10.2.0.2/24 on Gi2/0
6. Verify: `show mpls l2transport vc 300` on R17 and R18 — UP
7. Verify: R19 can ping R20 — pseudowire crosses R13-R16 core segment
8. You now have three independent pseudowires across the MPLS core

### Task 6: Multiple VCs on the Same Interface (VLAN-Based) - DONE

1. On R2: create sub-interfaces for Fa0/0:
   - First remove the existing xconnect from Fa0/0
   - `interface FastEthernet0/0.10` — encapsulation dot1Q 10
   - `xconnect 8.8.8.8 1010 encapsulation mpls` (VC for VLAN 10)
   - `interface FastEthernet0/0.20` — encapsulation dot1Q 20
   - `xconnect 8.8.8.8 1020 encapsulation mpls` (VC for VLAN 20)
2. On R8: mirror the sub-interface config on Gi1/0:
   - `interface GigabitEthernet1/0.10` — encapsulation dot1Q 10, xconnect 2.2.2.2 1010
   - `interface GigabitEthernet1/0.20` — encapsulation dot1Q 20, xconnect 2.2.2.2 1020
3. On R1: create sub-interfaces with matching VLANs and IPs:
   - Fa0/0.10 → 10.10.0.1/24 (VLAN 10)
   - Fa0/0.20 → 10.20.0.1/24 (VLAN 20)
4. On R9: same VLAN sub-interfaces:
   - Gi1/0.10 → 10.10.0.2/24 (VLAN 10)
   - Gi1/0.20 → 10.20.0.2/24 (VLAN 20)
5. Verify: R1 can ping R9 on VLAN 10 (10.10.0.2)
6. Verify: R1 can ping R9 on VLAN 20 (10.20.0.2)
7. Verify: VLAN 10 and VLAN 20 are separate pseudowires — different VC labels
8. `show mpls l2transport vc` — should show VC 1010 and VC 1020 both UP

---

## Section 3: Pseudowire Signalling and Control Plane

### Task 7: Understand LDP-Based Signalling (Targeted LDP) - DONE

1. On R2: `show mpls ldp neighbor 8.8.8.8 detail` — note this is a TARGETED LDP session (not link-based)
2. The pseudowire uses targeted LDP between PE loopbacks to exchange VC labels
3. This is different from link LDP (which exchanges transport labels with directly connected neighbors)
4. Verify: `show mpls ldp discovery` — shows both link discoveries and targeted discoveries
5. On R2: `show mpls l2transport vc 100 detail` — note:
   - Local label (what R2 assigns for incoming VC traffic)
   - Remote label (what R8 assigned — R2 uses this as VC label when sending)
   - Signalling protocol: LDP

### Task 8: VC Status and Troubleshooting  - DONE

1. On R8: shut the interface toward R9 (Gi1/0)
2. On R2: `show mpls l2transport vc 100` — status should change to DOWN
3. Note the reason: "remote attachment circuit down" or similar
4. On R2: the pseudowire signals the remote failure back via LDP notification
5. Bring R8's interface back — verify VC returns to UP
6. On R2: shut R2's Fa0/0 (local attachment circuit)
7. On R8: `show mpls l2transport vc 100` — status shows local AC down from R2's perspective
8. Bring back — verify recovery
9. **Troubleshooting flow:** if VC is DOWN, check:
   - Is the targeted LDP session UP? (`show mpls ldp neighbor`)
   - Is the local interface UP?
   - Is the remote interface UP?
   - Does the transport LSP to the peer exist? (`ping mpls ipv4 <peer-loopback>/32`)

---

## Section 4: Pseudowire with QoS - DONE

### Task 9: Set EXP Bits on Pseudowire Traffic

1. On R2: create a policy-map that marks pseudowire traffic:
   - `class-map match-all PW-VOICE` — match DSCP EF (if customer sends marked traffic)
   - `policy-map PW-MARKING` — set MPLS EXP 5 for voice, EXP 0 for everything else
2. Apply to the xconnect:
   - Under the interface or pseudowire class: `service-policy input PW-MARKING`
3. Verify: traffic from R1 with DSCP EF gets EXP 5 in the MPLS header
4. On R3 (P router): the core can now differentiate voice vs data pseudowire traffic based on EXP
5. If QoS on xconnect is not supported directly, apply the policy on the ingress physical interface

### Task 10: Pseudowire Bandwidth Shaping - DONE

1. On R2: create a policy-map that shapes pseudowire traffic to 50 Mbps:
   - `policy-map PW-SHAPE` → `class class-default` → `shape average 50000000`
2. Apply outbound on the tunnel/interface carrying the pseudowire
3. Verify: `show policy-map interface` — confirm shaping is active
4. This is how SPs enforce CIR (Committed Information Rate) on L2VPN services
5. Customer pays for 50 Mbps Ethernet Private Line → SP shapes to contracted rate

---

## Section 5: Pseudowire OAM

### Task 11: VCCV Ping — Test the Pseudowire Path - DONE

1. On R2: `ping mpls pseudowire 8.8.8.8 100` (ping the pseudowire with VC ID 100)
2. Verify: replies received — proves the VC label path is healthy end-to-end
3. If VCCV ping is not available: use `ping mpls ipv4 8.8.8.8/32` to verify transport, then `show mpls l2transport vc 100 detail` to verify VC status
4. Break the pseudowire: on R8, change VC ID to 999 (mismatch)
5. On R2: `show mpls l2transport vc 100` — should show DOWN (VC ID mismatch)
6. VCCV ping should now fail
7. Fix: restore correct VC ID on R8
8. Verify: VC returns to UP, VCCV ping succeeds again

### Task 12: Monitor Pseudowire with IP SLA - DONE 

1. On R2: create IP SLA probe for the pseudowire:
   - `ip sla 10`
   - `mpls lsp ping ipv4 8.8.8.8/32` (monitors the transport LSP to R8)
   - `frequency 30`
   - `ip sla schedule 10 start-time now life forever`
2. Verify: `show ip sla statistics 10` — tracks reachability over time
3. Create a track object: `track 10 ip sla 10 reachability`
4. This can trigger alerts or rerouting if the LSP to the pseudowire peer fails
5. **SP model:** automated monitoring of every customer L2VPN circuit, 24/7

---

## CCIE+ Challenges

### Challenge 1: L2VPN and L3VPN Coexisting on Same PE - DONE

1. R2 currently has pseudowires on Fa0/0 (L2VPN to R1) — reconfigure
2. Use sub-interfaces:
   - Fa0/0.10 (VLAN 10): xconnect to R8 — L2VPN service (pure L2)
   - Fa0/0.20 (VLAN 20): ip vrf forwarding Customer_A, IP address — L3VPN service
3. R1 uses VLAN 10 for L2 connectivity (gets a wire to R9)
4. R1 uses VLAN 20 for L3 routed connectivity (gets L3VPN to R9 via BGP)
5. Verify: both services work simultaneously on the same physical link
6. Verify: L2VPN traffic and L3VPN traffic are completely independent
7. **This is standard SP design:** one access port, multiple services via VLANs

### Challenge 2: Pseudowire Class Configuration - DONE

1. Create a pseudowire class for standardized settings:
   - `pseudowire-class STANDARD-PW`
   - `encapsulation mpls`
   - `control-word` (enables control word for sequencing)
2. Apply to all xconnects: `xconnect 8.8.8.8 100 pw-class STANDARD-PW`
3. Verify: `show mpls l2transport vc 100 detail` — control word enabled
4. **Control word purpose:** prevents ECMP load-balancing from reordering pseudowire packets
5. Without control word: if core has ECMP, frames may arrive out of order
6. With control word: P routers can identify it's a pseudowire and avoid reordering

### Challenge 3: MTU Considerations - DONE

1. Customer sends 1500-byte Ethernet frames through the pseudowire
2. The PE adds: 14 bytes Ethernet header (or keeps original) + 4 bytes VC label + 4 bytes transport label
3. Core interfaces need MTU > 1500 to avoid fragmentation
4. On all core interfaces: set `mpls mtu 1526` (or increase interface MTU to 9000 for jumbo)
5. Verify: R1 can ping R9 with `size 1500 df-bit` — no fragmentation
6. Reduce core MTU artificially — verify large pings fail (proves MTU matters)
7. Restore proper MTU — verify large pings succeed again

### Challenge 4: Local Switching (Hairpin Pseudowire) - DONE

1. On R2: create a local xconnect between two interfaces (no remote PE):
   - `connect LOCAL-SWITCH FastEthernet0/0 FastEthernet3/0`
   - Or: `xconnect` on Fa0/0 pointing to local interface
2. This connects R1 directly to R12 at L2 through R2 — without crossing the MPLS core
3. Verify: R1 and R12 (if on same subnet) can ping each other
4. Use case: two customer ports on the same PE that need L2 connectivity
5. Verify: `show connection name LOCAL-SWITCH` — status UP

### Challenge 5: Pseudowire Fragmentation and Reassembly - DONE

1. If customer sends jumbo frames (9000 bytes) but core MTU is 1500:
   - `pseudowire-class FRAGMENT-PW`
   - `encapsulation mpls`
   - `sequencing both`
2. Test with large ping from R1: `ping 10.0.0.2 size 8000 df-bit`
3. Without fragmentation support: large frames are dropped
4. Research: does IOS 15.2 on 7200 support pseudowire fragmentation? If not, document the concept.
5. **Production solution:** set core MTU to 9216 (jumbo frames) to avoid fragmentation entirely

---

## Final Validation

By the end of this lab, your network has:

- [x] Point-to-point EoMPLS pseudowire operational (R2↔R8, VC 100)
- [x] L2 transparency proven (any IP, broadcasts cross the pseudowire)
- [x] Label stack understood (transport + VC label, same concept as L3VPN)
- [x] Multiple pseudowires coexisting (VC 100, 200, 300 on different PE pairs)
- [x] Complete isolation between pseudowires (no cross-contamination)
- [x] VLAN-based pseudowires (multiple VCs on one physical interface)
- [x] Targeted LDP signalling understood (VC label exchange between PE loopbacks)
- [x] Pseudowire status monitoring and failure detection
- [x] QoS marking (EXP bits) applied to pseudowire traffic
- [x] VCCV or IP SLA monitoring the pseudowire health
- [x] (CCIE+) L2VPN and L3VPN coexisting on same PE/interface
- [x] (CCIE+) Control word preventing ECMP reordering
- [x] (CCIE+) MTU planning for label overhead verified
- [x] (CCIE+) Local switching (hairpin) for same-PE L2 connectivity
