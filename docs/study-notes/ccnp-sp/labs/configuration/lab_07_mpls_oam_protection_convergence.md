# Lab 7: MPLS OAM, Protection & Convergence — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers. Focus on operational tools and protection mechanisms.
**Prerequisite:** Lab 1 complete (OSPF + LDP running), Lab 2 complete (L3VPN operational)

**End Goal:** A hardened MPLS network with comprehensive OAM (Operations, Administration, Maintenance) tools deployed, LDP protection mechanisms active, and convergence optimized to sub-second failover. By the end, you can diagnose any MPLS forwarding issue without guessing, and your network self-heals within milliseconds of a failure.

---

## Section 1: MPLS OAM — LSP Ping and Traceroute

### Task 1: LSP Ping — Verify the Data Plane

1. From R2: `ping mpls ipv4 8.8.8.8/32` — this tests the MPLS LSP to R8's loopback
2. Observe: the echo request travels in-band (through the LSP), reply returns via IP
3. Verify: all hops respond — if any hop returns "!" the LSP is healthy
4. Compare with regular `ping 8.8.8.8` — both work, but LSP ping tests the LABEL path specifically
5. From R2: `ping mpls ipv4 17.17.17.17/32` — verify LSP to R17
6. From R2: `ping mpls ipv4 18.18.18.18/32` — verify LSP to R18
7. Test a broken path: on R5, remove `mpls ip` from one interface. Re-run LSP ping — observe the failure message identifying WHERE the break is
8. Restore `mpls ip` — confirm LSP ping returns to healthy

### Task 2: MPLS Traceroute — Map the Label Path

1. From R2: `traceroute mpls ipv4 8.8.8.8/32` — observe each hop with its incoming/outgoing labels
2. Note: each hop reports the label it received AND the label it swapped to (or popped)
3. From R8: `traceroute mpls ipv4 2.2.2.2/32` — trace in the reverse direction
4. Compare both traces: the paths should be symmetric (same hops in reverse) if OSPF costs are equal
5. From R17: `traceroute mpls ipv4 8.8.8.8/32` — trace across a longer path
6. Identify: at which hop does PHP (Penultimate Hop Popping) occur? (Second-to-last hop pops the label)
7. Verify: the last hop in the trace shows "implicit-null" or "3" as the outgoing label

### Task 3: VRF-Aware LSP Testing

1. From R2: `ping mpls ipv4 8.8.8.8/32 fec-type ldp` — tests the LDP LSP
2. Now test the VPN label path: `ping vrf Customer_A 9.9.9.9`
3. On R2: `show ip cef vrf Customer_A 9.9.9.9` — note the two-label stack (transport + VPN)
4. There is no direct "ping mpls" for VPN paths, but you can verify by:
   - Confirming the transport LSP is healthy (Task 1)
   - Confirming the VPN label binding exists: `show ip bgp vpnv4 vrf Customer_A labels`
5. If VPN ping fails but LSP ping succeeds: the problem is in the VPN label, not the transport
6. If both fail: the problem is in the transport LSP
7. This diagnostic flow is how you isolate VPN forwarding issues in production

---

## Section 2: TTL Propagation and Security

### Task 4: Understand TTL Behaviour in MPLS

1. From R1 (CE): `traceroute 9.9.9.9` — observe: do you see the P router hops? Or do they appear as `* * *`?
2. Check R2 configuration: `show run | include mpls ip propagate-ttl`
3. Default behaviour on IOS: TTL is propagated (CE sees all hops)
4. On R2: `no mpls ip propagate-ttl forwarded` — disable TTL propagation for forwarded (transit) packets
5. From R1: repeat `traceroute 9.9.9.9` — now P routers should be HIDDEN (only ingress PE and egress PE visible)
6. The trace should show: R1 → R2 → R8 → R9 (core hidden)
7. Security benefit: attackers cannot map your SP core topology from a CE

### Task 5: Selective TTL Propagation

1. Current state: `no mpls ip propagate-ttl forwarded` hides core from transit traffic
2. From R2 (PE): `traceroute 8.8.8.8` — can R2 still see core hops?
3. Configure: `no mpls ip propagate-ttl local` — also hide core for locally-originated MPLS packets
4. From R2: repeat `traceroute 8.8.8.8` — now even PE can't see intermediate hops
5. Revert `local` setting — PE operators need to see the core for troubleshooting
6. Keep `no mpls ip propagate-ttl forwarded` — CEs/customers shouldn't see core
7. Verify final state: PE can trace through core (all hops visible), CE cannot (core hidden)

### Task 6: TTL and MPLS TE Tunnels

1. Prerequisite: have a TE tunnel UP from Lab 3 (or create Tunnel0 R2→R8 dynamic)
2. On R2: `tunnel mpls traffic-eng path-option 1 dynamic`
3. From R1: traceroute to 9.9.9.9 with traffic riding the TE tunnel
4. Check: does the traceroute show tunnel hops or is the entire tunnel one hop?
5. Configure: `no mpls ip propagate-ttl` — trace again
6. The TE tunnel should appear as a SINGLE HOP in the traceroute (entire tunnel compressed)
7. This is standard SP behaviour: customers see "PE → PE" regardless of how many core hops exist

---

## Section 3: LDP Session Protection

### Task 7: LDP Session Protection (Targeted Hellos)

1. On R2: `mpls ldp session protection duration infinite`
2. On R3: `mpls ldp session protection duration infinite`
3. Verify: `show mpls ldp neighbor 3.3.3.3 detail` — note "targeted hello" state
4. Now shut the direct link between R2 and R3 (Gi1/0 on R2, ip 172.16.23.1)
5. Verify: the LDP session between R2 and R3 STAYS UP (maintained via targeted hellos over alternate IGP path)
6. Check: `show mpls ldp neighbor` — session still established despite direct link down
7. Verify: labels from R3 are still in R2's LFIB — `show mpls forwarding-table` still has entries with R3 as next-hop
8. Bring the link back — verify targeted hello reverts to link hello
9. **Without** session protection: repeat the test (remove the config, shut link) — LDP session drops immediately

### Task 8: LDP IGP Synchronization

1. On R2, under OSPF interface Gi1/0 (toward R3): `mpls ldp igp sync`
2. On R3, under OSPF interface Gi1/0 (toward R2): `mpls ldp igp sync`
3. Now shut and immediately bring up R2's Gi1/0 toward R3
4. Observe: OSPF advertises the link with MAX METRIC until LDP session is re-established
5. Check: `show mpls ldp igp sync` — shows sync state per interface
6. Once LDP is synced: OSPF reverts to normal metric — traffic can use the link
7. **Why this matters:** without IGP sync, traffic could be sent to a link where MPLS isn't ready yet, causing drops
8. Enable on ALL core interfaces: every P and PE router, every core-facing interface

### Task 9: LDP Downstream-on-Demand vs Unsolicited

1. Check current mode: `show mpls ldp parameters` — note "Label advertisement mode"
2. Default on IOS: "downstream unsolicited" (labels sent without being asked)
3. Observe label count: `show mpls ldp bindings | count` — every prefix has a label from every neighbor
4. Configure R2: `mpls ldp label advertise for ACL-LOOPBACKS to ACL-CORE-PEERS`
   - ACL-LOOPBACKS: permits only /32 loopbacks
   - ACL-CORE-PEERS: permits only LDP neighbor addresses
5. Verify: label table on R2 shrinks — only loopback labels advertised (not transit links)
6. Verify: VPN still works (VPN only needs loopback labels for BGP next-hops)
7. **This reduces LFIB size significantly** in large networks

---

## Section 4: MPLS Convergence Optimization

### Task 10: LDP-IGP Convergence (Loop-Free Alternates)

1. On R2: enable OSPF LFA (Loop-Free Alternate):
   - Under OSPF: `fast-reroute per-prefix enable area 0`
2. On R2: `show ip ospf fast-reroute` — verify LFA is computing backup paths
3. Check: `show ip route 8.8.8.8` — look for "repair path" showing the pre-computed backup
4. Verify: `show ip cef 8.8.8.8 internal` — backup next-hop is installed in CEF
5. Kill the primary next-hop link from R2 (e.g., shut Gi1/0 toward R3)
6. Measure: traffic to R8 should converge to backup in < 100ms (CEF switches immediately)
7. Compare with default OSPF convergence (wait for SPF + LDP sync = seconds)
8. Bring link back — verify primary path restores
9. Repeat on all PE routers for comprehensive LFA coverage

### Task 11: BFD for Sub-Second Failure Detection

1. On R2 and R3 (link Gi1/0): enable BFD:
   - Under interface: `bfd interval 300 min_rx 300 multiplier 3` (900ms detection)
2. On R2: `router ospf 1` → `bfd all-interfaces` (OSPF registers with BFD)
3. On R3: same BFD + OSPF integration
4. Verify: `show bfd neighbors` on R2 — session to R3 is UP
5. Shut R3's interface toward R2 — observe BFD detects failure in ~900ms
6. Check: `show ip ospf neighbor` — R3 neighbor goes DOWN almost immediately (BFD triggers)
7. Compare: without BFD, OSPF dead timer is 40 seconds (default)
8. Deploy BFD on all critical core links (PE-to-P minimum)
9. Verify: `show bfd neighbors` shows sessions to all directly connected OSPF neighbors

### Task 12: MPLS LDP Graceful Restart

1. On R2: `mpls ldp graceful-restart`
2. On R3: `mpls ldp graceful-restart`
3. Verify: `show mpls ldp neighbor 3.3.3.3 detail | include Graceful`
4. On R3: `clear mpls ldp neighbor *` — force LDP session reset
5. During restart: check R2's LFIB — `show mpls forwarding-table`
   - Labels from R3 should be retained as "stale" during the restart timer
6. Verify: traffic from R1 to R9 continues flowing DURING the LDP restart (stale labels used)
7. After session re-establishes: stale labels are refreshed or removed
8. **Without graceful restart:** repeat — LDP reset causes immediate label withdrawal = traffic blackhole

---

## Section 5: Advanced Troubleshooting Scenarios

### Task 13: Diagnose a VPN Blackhole

1. On R5: manually break the MPLS forwarding — `no mpls ip` on interface toward R8 (Gi2/0)
2. From R1: ping R9 — should fail (blackhole in the core)
3. Troubleshooting flow:
   - Step 1: `ping mpls ipv4 8.8.8.8/32` from R2 — identifies the break is between R5 and R8
   - Step 2: `traceroute mpls ipv4 8.8.8.8/32` from R2 — shows exactly which hop fails
   - Step 3: On R5: `show mpls interfaces` — identifies which interface lost MPLS
4. Fix: re-enable `mpls ip` on R5 Gi2/0
5. Verify: LSP ping succeeds, VPN traffic flows again

### Task 14: Diagnose a Label Mismatch

1. On R3: change the label range — `mpls label range 900 999` (was 300-399)
2. Clear LDP neighbors: `clear mpls ldp neighbor *`
3. After labels re-allocate: some stale CEF entries may cause misforwarding
4. From R2: `ping mpls ipv4 8.8.8.8/32` — does it fail?
5. Troubleshoot: `show mpls forwarding-table` on R3 — compare local labels with what R2 expects
6. On R2: `show mpls ldp bindings 3.3.3.3 32` — verify the label R2 has for R3 matches R3's local binding
7. If mismatch: `clear ip route *` and `clear mpls ldp neighbor *` to force reconvergence
8. Restore original label range: `mpls label range 300 399`
9. Verify: all labels consistent, LSP ping succeeds end-to-end

### Task 15: Verify End-to-End MPLS MTU

1. On R2: `ping mpls ipv4 8.8.8.8/32 sweep 1400 1500 10` — tests progressively larger MPLS packets
2. Identify: at what size does the ping fail? (This reveals the MPLS MTU along the path)
3. Remember: MPLS adds 4 bytes per label. Two-label stack (VPN) = 8 bytes overhead
4. If core interfaces have MTU 1500: effective VPN MTU = 1500 - 8 = 1492
5. Verify: `show mpls mtu` on each interface (if available) or check interface MTU
6. From R1: `ping 9.9.9.9 size 1492 df-bit` — should succeed (fits in MPLS MTU)
7. From R1: `ping 9.9.9.9 size 1500 df-bit` — may fail or fragment (depends on interface MTU configuration)
8. Fix: set `mpls mtu 1508` on all core interfaces (allows 1500-byte payloads + 8 bytes of labels without fragmentation)

---

## CCIE+ Challenges

### Challenge 1: MPLS OAM for VPN SLA Monitoring

1. Create a periodic LSP ping that runs automatically (IP SLA with MPLS):
   - `ip sla 1` → `mpls lsp ping ipv4 8.8.8.8/32`
   - `frequency 30`
   - `ip sla schedule 1 start-time now life forever`
2. Verify: `show ip sla statistics 1` — shows success/failure history
3. Create a second IP SLA for R17: `mpls lsp ping ipv4 17.17.17.17/32`
4. Set up a track object: `track 1 ip sla 1 reachability`
5. Combine with a static route: if LSP to R8 fails, traffic reroutes automatically
6. This is how SPs monitor LSP health in production without waiting for customer complaints

### Challenge 2: LDP Session Protection Under Complex Failure

1. Enable `mpls ldp session protection` on ALL core routers
2. Enable `mpls ldp igp sync` on ALL core interfaces
3. Simulate a dual-link failure: shut TWO links from R3 simultaneously
4. Verify: LDP sessions to R3 survive (if alternate IP path exists)
5. Verify: OSPF does NOT forward to links without LDP sync
6. Bring both links back — verify clean reconvergence
7. Now simulate R3 total failure (shut all interfaces) — LDP sessions drop (no alternate path TO R3)
8. Verify: other routers reconverge around R3 without blackholing traffic during LDP re-establishment

### Challenge 3: Comprehensive BFD + LFA + LDP-Sync Stack

1. Deploy the full protection stack on every core link:
   - BFD (300ms intervals, multiplier 3 = 900ms detection)
   - OSPF LFA (fast-reroute per-prefix)
   - LDP IGP sync
   - LDP session protection
2. Kill a random core link (e.g., R6→R7)
3. Measure end-to-end reconvergence: ping from R1 to R9 with timestamp
4. Target: < 1 second total convergence (BFD detects in 900ms, LFA switches in <50ms)
5. Repeat for three different link failures — verify consistent sub-second failover
6. This is the CCIE-SP "full stack" protection that examiners expect you to deploy

### Challenge 4: MPLS Pseudowire OAM (VCCV)

1. If your IOS supports VCCV (Virtual Circuit Connectivity Verification):
   - Create a simple L2VPN pseudowire between R2 and R8
   - `ping mpls pseudowire <peer-address> <vc-id>`
2. This tests the pseudowire label path specifically (not just the transport LSP)
3. Verify: VCCV ping succeeds when pseudowire is UP
4. Break the pseudowire (remove config on one end) — VCCV ping fails
5. If VCCV not supported on IOS 15.2: document the concept and what you'd test on IOS-XR/XE

### Challenge 5: Graceful Restart Under Load

1. Enable graceful restart on ALL LDP sessions
2. Run continuous VPN traffic: R1 pinging R9, R12 pinging R11, R19 pinging R20 (all VPNs active)
3. On R5 (central P router): `clear mpls ldp neighbor *` — force all LDP sessions to restart
4. Measure: how many pings are lost across ALL three VPN streams during the restart?
5. Target: 0-2 packets lost per stream (graceful restart preserves forwarding)
6. Without graceful restart: repeat — measure packet loss (should be significantly higher)
7. Compare: graceful restart timer values and their impact on convergence time

---

## Final Validation

By the end of this lab, your network has:

- [ ] LSP ping operational from every PE to every other PE (4 PEs, all pairs verified)
- [ ] MPLS traceroute showing complete label path with PHP identification
- [ ] TTL propagation disabled for forwarded traffic (core hidden from CEs)
- [ ] TTL propagation enabled for local traffic (PEs can still trace through core)
- [ ] LDP session protection active on all core routers (sessions survive link failure)
- [ ] LDP-IGP sync enabled (no traffic sent to links without MPLS)
- [ ] BFD deployed on all core links (sub-second failure detection)
- [ ] OSPF LFA computing backup paths (pre-installed in CEF)
- [ ] LDP graceful restart preserving forwarding during session restarts
- [ ] MPLS MTU verified and corrected (1500-byte payloads pass cleanly)
- [ ] Diagnostic skills: can isolate VPN vs transport failures using LSP ping
- [ ] (CCIE+) IP SLA MPLS probes for automated LSP monitoring
- [ ] (CCIE+) Full protection stack (BFD + LFA + LDP-sync + session protection) deployed
- [ ] (CCIE+) Sub-second convergence verified under multiple failure scenarios
- [ ] (CCIE+) Graceful restart preserving all VPN traffic during LDP restarts
