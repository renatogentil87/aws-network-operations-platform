# Lab 3: MPLS Traffic Engineering — Workbook

**Platform:** GNS3 Local (Cisco 7200)
**Topology:** 20 routers — Focus on core P routers and PE-to-PE tunnels

---

## Task 1: Enable MPLS TE on the Core

1. Enable `mpls traffic-eng tunnels` globally on all P and PE routers
2. Under OSPF process 1, enable `mpls traffic-eng router-id Loopback0` and `mpls traffic-eng area 0` on all P and PE routers
3. Enable `mpls traffic-eng tunnels` on all core-facing interfaces (P-to-P and PE-to-P)
4. Enable `ip rsvp bandwidth` on all core-facing interfaces (match the physical bandwidth)
5. Verify: `show mpls traffic-eng topology` on R2 — all P and PE routers should appear with their links
6. Verify: `show ip rsvp interface` on every router — all TE-enabled interfaces listed

---

## Task 2: Dynamic Tunnel

1. Create Tunnel0 on R2 with destination 8.8.8.8 (R8 loopback)
2. Set path-option 1 dynamic
3. Set tunnel bandwidth to 1000 kbps
4. Enable autoroute announce
5. Verify: Tunnel0 is up — `show mpls traffic-eng tunnels tun0`
6. Verify: which path CSPF selected (should follow lowest TE metric)
7. Traceroute from R2 to 8.8.8.8 — confirm traffic goes through the tunnel
8. Compare the tunnel path with normal IGP shortest path — are they the same?

---

## Task 3: Explicit Path Tunnel

1. Create an explicit path named "R2-to-R8-via-R4" forcing: R2→R3→R4→R5→R8
2. Create Tunnel1 on R2 with destination 8.8.8.8
3. Set path-option 1 explicit name R2-to-R8-via-R4
4. Set tunnel bandwidth to 1000 kbps
5. Verify: Tunnel1 is up and using the explicit path
6. Traceroute from R2 to 8.8.8.8 — confirm traffic follows R3→R4→R5→R8
7. Verify this is DIFFERENT from the dynamic path (Task 2)

---

## Task 4: Primary and Backup Paths

1. On Tunnel0, configure two path options:
   - Path-option 1: explicit path R2→R3→R4→R5→R8 (primary)
   - Path-option 2: explicit path R2→R6→R7→R8 (backup)
2. Verify: Tunnel0 is using path-option 1
3. Shut a link in the primary path (e.g., shut R4's interface toward R5)
4. Verify: Tunnel0 fails over to path-option 2
5. Start a continuous ping from R1 to R9 — count how many packets are lost during failover
6. Bring the link back up
7. Force reoptimization: `mpls traffic-eng reoptimize`
8. Verify: Tunnel0 returns to path-option 1

---

## Task 5: Bandwidth Reservation and Admission Control

1. Set Tunnel0 bandwidth to 90000 kbps
2. Verify: tunnel is up and bandwidth is reserved
3. Check `show ip rsvp interface` on each hop — confirm bandwidth allocated
4. Create Tunnel2 on R2 to R8 with bandwidth 90000 kbps using the SAME explicit path
5. Verify: Tunnel2 should FAIL — not enough bandwidth on the shared links
6. Check the error: `show mpls traffic-eng tunnels tun2`
7. Reduce Tunnel2 bandwidth to fit within remaining capacity
8. Verify: both tunnels now coexist

---

## Task 6: Affinity Bits (Link Colouring)

1. Assign attribute flags to links:
   - All GigabitEthernet links: `mpls traffic-eng attribute-flags 0x1` (colour "red")
   - All FastEthernet links: `mpls traffic-eng attribute-flags 0x2` (colour "blue")
2. Create a tunnel that AVOIDS red links: `tunnel mpls traffic-eng affinity 0x0 mask 0x1`
3. Verify: tunnel only uses FastEthernet (blue) links
4. Create a tunnel that REQUIRES red links: `tunnel mpls traffic-eng affinity 0x1 mask 0x1`
5. Verify: tunnel only uses GigabitEthernet (red) links
6. Verify: `show mpls traffic-eng topology` shows attribute flags per link

---

## Task 7: Preemption

1. Create Tunnel_Low on R2 to R8 with priority 7 7 (setup 7, hold 7) and bandwidth 80000
2. Verify: Tunnel_Low is up and reserving bandwidth
3. Create Tunnel_High on R2 to R8 with priority 0 0 (setup 0, hold 0) and bandwidth 80000 on the SAME path
4. Verify: Tunnel_High preempts Tunnel_Low (takes the bandwidth)
5. Verify: Tunnel_Low goes down or falls to backup path
6. Check: `show ip rsvp reservation` — who holds the reservation now?
7. Remove Tunnel_High — does Tunnel_Low recover?

---

## Task 8: TE Tunnel Carrying VPN Traffic

1. Ensure Tunnel0 has `autoroute announce` configured
2. Ensure BGP vpnv4 next-hop between R2 and R8 is their loopbacks (8.8.8.8 / 2.2.2.2)
3. From R1 (CE), traceroute to R9 loopback (9.9.9.9)
4. Verify: VPN traffic follows the TE tunnel path (not the IGP shortest path)
5. Check R2: `show ip cef vrf Customer_A 9.9.9.9` — should show Tunnel0 as outgoing interface
6. Shut the tunnel — verify VPN traffic falls back to normal IGP path
7. Bring tunnel back — verify VPN traffic returns through tunnel

---

## Task 9: Auto-Bandwidth

1. Configure auto-bandwidth on Tunnel0:
   - Max bandwidth: 500000
   - Min bandwidth: 1000
   - Adjustment threshold: 10%
2. Generate traffic through the tunnel (continuous ping flood from R1 to R9)
3. Wait for auto-bandwidth adjustment interval
4. Verify: tunnel bandwidth reservation increases
5. Stop the traffic
6. Wait for next adjustment
7. Verify: tunnel bandwidth reservation decreases back to minimum

---

## Task 10: TE Metric vs IGP Metric

1. On one core link, set a high TE administrative weight: `mpls traffic-eng administrative-weight 5000`
2. Keep the IGP metric unchanged on that link
3. Create a dynamic tunnel — verify it AVOIDS the high-TE-metric link
4. Traceroute normally (without tunnel) — verify IGP routing STILL USES that link
5. Proves: TE path calculation is independent from IGP forwarding

---

## Validation Checklist

- [ ] Dynamic tunnel comes up and follows CSPF-computed path
- [ ] Explicit path tunnel follows the defined hops exactly
- [ ] Failover from primary to backup path works (< 5 packets lost)
- [ ] Reoptimization returns traffic to primary path
- [ ] Bandwidth admission control rejects tunnels that exceed capacity
- [ ] Affinity bits correctly include/exclude links
- [ ] High-priority tunnel preempts low-priority tunnel
- [ ] VPN traffic flows through TE tunnel via autoroute
- [ ] Auto-bandwidth adjusts reservation based on traffic
- [ ] TE metric and IGP metric operate independently

---

## CCIE+ Challenge Tasks

### Challenge 1: DS-TE (DiffServ-Aware Traffic Engineering)
- Configure two bandwidth pools on interfaces: Global Pool and Sub Pool
- `ip rsvp bandwidth <global> sub-pool <sub-pool>`
- Create a tunnel using global pool (best-effort traffic)
- Create a second tunnel using sub-pool (premium traffic): `tunnel mpls traffic-eng bandwidth sub-pool 50000`
- Verify: both tunnels reserve from their respective pools
- Oversubscribe the sub-pool — verify only sub-pool tunnel fails, global pool tunnel unaffected

### Challenge 2: MPLS TE with IS-IS (Instead of OSPF)
- Replace OSPF with IS-IS on the core (all P and PE routers)
- Enable TE extensions for IS-IS: `mpls traffic-eng router-id Loopback0` + `mpls traffic-eng level-2`
- Verify: TE topology database still populated
- Verify: tunnels still work with IS-IS as the IGP
- Compare: `show isis database detail` — observe TE TLVs (different from OSPF opaque LSAs)

### Challenge 3: Inter-Area TE with Loose Hops
- Split OSPF into Area 0 (R2, R3, R4) and Area 1 (R5, R6, R7, R8)
- R4 and R5 are ABRs
- Build a tunnel from R2 to R8 crossing areas
- Use loose hops at area boundaries: `next-address loose 5.5.5.5` then `next-address loose 8.8.8.8`
- Verify: tunnel signals across areas using ABR as loose-hop expansion point
- Verify: CSPF computes within each area independently

### Challenge 4: RSVP Authentication and Security
- Enable RSVP authentication between R2 and R3: `ip rsvp authentication key <key>`
- Verify: tunnel still signals (both ends have matching keys)
- Misconfigure the key on one side — verify tunnel fails to signal
- Proves: RSVP messages can be authenticated to prevent spoofing

### Challenge 5: Make-Before-Break Verification
- Tunnel0 is up on path 1
- Change the explicit path to a different set of hops
- Verify: tunnel signals the NEW path BEFORE tearing down the old one
- During the transition: continuous ping should show ZERO packet loss
- `show mpls traffic-eng tunnels tun0 detail` — observe "Prior LSP" during transition

### Challenge 6: TE + VPN + FRR Combined Scenario
- VPN traffic from R1 to R9 flows through TE tunnel (autoroute)
- TE tunnel has FRR enabled with backup on transit router
- Kill a link in the tunnel's primary path
- Measure: packet loss from R1 to R9 should be 0-1 packets (FRR protects the TE tunnel, which carries the VPN)
- This is the full production stack: VPN over TE with FRR protection

### Challenge 7: Forwarding Adjacency
- Remove autoroute announce from Tunnel0
- Configure `tunnel mpls traffic-eng forwarding-adjacency` instead
- Verify: Tunnel0 appears as an OSPF adjacency in the IGP
- Verify: other routers see the tunnel as a link in their SPF calculation
- Compare IGP routing table before and after — what changed?
- When would you use forwarding-adjacency vs autoroute? (Hint: affects other routers' paths)
