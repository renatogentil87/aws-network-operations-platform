# Lab 6: Advanced L3VPN — Multi-Topology VPN Design — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs (R2, R8, R17, R18), 9 P routers, 7 CEs across 5 VRFs
**Prerequisite:** Lab 2 complete (5 customers fully isolated, RRs in place, mixed PE-CE protocols working)

**End Goal:** A production-grade SP VPN service with shared services infrastructure, hub-and-spoke topologies, multi-homed CEs with proper loop prevention, and extranet route leaking. By the end, you're running the same VPN design patterns that real SPs deploy for enterprise customers.

---

## Section 1: Shared Services — Controlled Inter-VRF Access

### Task 1: Create the Shared Services VRF

1. On R2: create VRF "Shared_Services" with RD 64512:999
2. Set route-target export 64512:999
3. Set route-target import 64512:999
4. Create Loopback99 in VRF Shared_Services with IP 100.100.100.1/32 (simulates DNS server)
5. Create Loopback98 in VRF Shared_Services with IP 100.100.200.1/32 (simulates NTP server)
6. Redistribute connected into BGP under VRF Shared_Services so both loopbacks are advertised
7. Verify: `show ip bgp vpnv4 vrf Shared_Services` — both loopbacks appear with RT 64512:999

### Task 2: Grant Customer_A Access to Shared Services

1. On R2: under VRF Customer_A, add `route-target import 64512:999`
2. On R8: under VRF Customer_A, add `route-target import 64512:999`
3. Verify: `show ip route vrf Customer_A` on R2 — 100.100.100.1 and 100.100.200.1 now appear
4. Verify: R1 (Customer_A CE) can ping 100.100.100.1
5. Verify: R9 (Customer_A CE) can ping 100.100.200.1
6. Verify: Customer_A CEs can reach shared services from ANY site

### Task 3: Grant Customer_B Access — Prove Isolation Holds

1. On R2: under VRF Customer_B, add `route-target import 64512:999`
2. On R8: under VRF Customer_B, add `route-target import 64512:999`
3. Verify: R12 (Customer_B CE) can ping 100.100.100.1 (shared services)
4. Verify: R11 (Customer_B CE) can ping 100.100.200.1 (shared services)
5. **Critical test:** R1 (Customer_A) still CANNOT ping R12 (Customer_B) — customers remain isolated
6. **Critical test:** R12 CANNOT ping R1 — no cross-contamination between customers
7. Verify: `show ip route vrf Customer_A` has shared services routes but NO Customer_B routes
8. Verify: `show ip route vrf Customer_B` has shared services routes but NO Customer_A routes

### Task 4: Make Shared Services Reach Back to Customers

1. Current state: customers can reach shared services, but shared services cannot initiate to customers
2. On R2: under VRF Shared_Services, add `route-target import 64512:100` (import Customer_A routes)
3. On R2: under VRF Shared_Services, add `route-target import 64512:200` (import Customer_B routes)
4. Verify: `show ip route vrf Shared_Services` on R2 — Customer_A and Customer_B routes appear
5. Verify: from the Shared_Services VRF, you can reach R1 (1.1.1.1) and R12 (12.12.12.12)
6. **This is a DESIGN DECISION** — the shared services VRF sees ALL customer routes, but customers still can't see each other. The VRF topology is: star with shared services at the center.

---

## Section 2: Hub-and-Spoke VPN Topology

### Task 5: Redesign Customer_A as Hub-and-Spoke

1. Designate R1 as the HUB site and R9 as a SPOKE site for Customer_A
2. On R2 (hub PE): change VRF Customer_A RT configuration:
   - Export RT: 64512:100 (hub routes tagged as 64512:100)
   - Import RT: 64512:101 (hub PE only accepts spoke-tagged routes)
3. On R8 (spoke PE): change VRF Customer_A RT configuration:
   - Export RT: 64512:101 (spoke routes tagged as 64512:101)
   - Import RT: 64512:100 (spoke PE only accepts hub-tagged routes)
4. Verify: R9 (spoke) can ping R1 (hub) — spoke-to-hub works
5. Verify: R1 (hub) can ping R9 (spoke) — hub-to-spoke works
6. Verify: `show ip route vrf Customer_A` on R8 — only R1's routes appear (hub routes)

### Task 6: Add a Second Spoke

1. On R17: create VRF Customer_A with RD 64512:100
   - Export RT: 64512:101 (spoke)
   - Import RT: 64512:100 (accepts hub routes)
2. Configure eBGP between R19 (AS 65019) and R17 under VRF Customer_A
3. On R19: advertise loopback 19.19.19.19 via BGP
4. Verify: R19 (spoke 2) can ping R1 (hub)
5. Verify: R1 (hub) can ping R19 (spoke 2)
6. **Critical test:** R9 CANNOT ping R19 directly — spoke-to-spoke blocked
7. Traceroute from R9 to 19.19.19.19 — traffic should go R9→R8→MPLS→R2→R1→R2→MPLS→R17→R19 (hairpin through hub)
8. If spoke-to-spoke fails completely (no hairpin): you need to enable the hub CE (R1) to re-advertise spoke routes back to R2, and R2 must re-export them with RT 64512:100

### Task 7: Verify Hub-and-Spoke Traffic Flow

1. On R1 (hub CE): ensure R1 re-advertises R9's routes and R19's routes back to R2
2. Start continuous ping from R9 to R19 (19.19.19.19)
3. Traceroute from R9 to R19 — verify traffic transits through R1 (the hub)
4. This proves: spoke-to-spoke traffic is forced through the hub for policy enforcement
5. On R1: you could place a firewall here to inspect all inter-spoke traffic (this is the design intent)
6. Verify: shut R1's interface — both spokes lose connectivity to each other AND to hub

---

## Section 3: Multi-Homed CEs and Loop Prevention

### Task 8: Dual-Attach R1 to Two PEs

1. Reconfigure Customer_A back to full-mesh RT (64512:100 export/import on all PEs) to simplify this section
2. R1 is currently connected to R2 via Fa0/0 (192.168.12.0/30)
3. Add a second PE-CE link: connect R1 to R17 — use R17's Fa3/0 (192.168.19.0/30 subnet — repurpose temporarily, or add a new interface)
   - **Note:** In your topology, R17 Fa3/0 connects to R19. If no spare interface exists, simulate by configuring R19 as a transit between R1 and R17, or skip to SOO theory.
   - **Alternative:** Multi-home R9 instead — R9 to R8 (existing) and R9 to R5 via a new link (if interface available on R5)
4. Configure eBGP between R1 and the second PE under VRF Customer_A
5. R1 advertises the same loopbacks (1.1.1.1, 11.11.11.11) to BOTH PEs
6. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — verify TWO paths exist (via R2 and via second PE)
7. Verify: traffic to R1 uses the preferred path (shortest AS-PATH or lowest IGP cost to next-hop)

### Task 9: Influence Path Preference with AS-PATH Prepend

1. On R1: create a route-map for the BGP session toward the secondary PE
2. In the route-map: `set as-path prepend 65001 65001 65001` (make this path look longer)
3. Apply outbound on R1's session to secondary PE
4. Verify: R8 now strongly prefers path via R2 (shorter AS-PATH)
5. Check: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` on R8 — compare AS-PATH lengths
6. Shut R1's link to R2 (primary failure)
7. Verify: R8 switches to path via secondary PE (longer AS-PATH, but only available path)
8. Bring R1's link to R2 back — verify traffic returns to primary

### Task 10: Site of Origin (SOO) — Prevent Routing Loops

1. Problem: with R1 multi-homed, R1's routes advertised to R2 get reflected to R17, which could advertise them BACK to R1 — creating a loop
2. On R2: under VRF Customer_A PE-CE session with R1, apply route-map setting SOO:
   - `set extcommunity soo 64512:1`
3. On R17 (or secondary PE): apply same SOO value for R1's routes:
   - `set extcommunity soo 64512:1`
4. Verify: R1's routes received by R2 carry SOO 64512:1
5. Verify: R17 will NOT re-advertise routes with SOO 64512:1 back to R1 (loop prevented)
6. Verify: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` on any PE — SOO extended community visible
7. Verify: R9 still reaches R1 — SOO doesn't break forwarding, only prevents loops

---

## Section 4: Extranet — Selective Cross-VPN Route Sharing

### Task 11: One-Way Prefix Sharing Between Customers

1. **Scenario:** Customer_A (R1) wants to share its DNS server (simulated by loopback 11.11.11.11) with Customer_B (R12), but nothing else
2. On R2: create a route-map "EXTRANET_EXPORT" that:
   - Matches prefix 11.11.11.11/32 with a prefix-list
   - Sets an additional route-target: 64512:200 (Customer_B's import RT)
3. Apply as export-map under VRF Customer_A: `export map EXTRANET_EXPORT`
4. Verify: `show ip bgp vpnv4 vrf Customer_A 11.11.11.11` — route now carries BOTH RT 64512:100 AND RT 64512:200
5. Verify: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — this route still carries only RT 64512:100
6. Verify: R12 (Customer_B) can ping 11.11.11.11 (the shared prefix)
7. Verify: R12 CANNOT ping 1.1.1.1 (not shared — only RT 64512:100, which Customer_B doesn't import)

### Task 12: Prove Extranet is One-Way

1. Verify: R1 (Customer_A) CANNOT ping R12's routes (12.12.12.12) — Customer_A does not import RT 64512:200
2. This is one-way sharing: Customer_B can reach Customer_A's shared prefix, but not vice versa
3. To make it bidirectional: on R2, under VRF Customer_A, add `route-target import 64512:200` — but only if the business requires it
4. **Do NOT add it** — keep the extranet one-way for this lab
5. Verify final state: Customer_B has exactly ONE route from Customer_A (11.11.11.11) and nothing else

---

## Section 5: Internet Access Design

### Task 13: Default Route Injection for VPN Customers

1. On R2: create a static route in VRF Customer_A:
   - `ip route vrf Customer_A 0.0.0.0 0.0.0.0 GigabitEthernet2/0 172.16.26.2 global`
   - This says: "VRF Customer_A default route exits via global table interface toward R6" (simulating internet uplink)
2. Under BGP VRF Customer_A on R2: `redistribute static`
3. Verify: R1 receives a default route (0.0.0.0/0) via eBGP from R2
4. Verify: `show ip route` on R1 — default route present with next-hop R2
5. From R1: ping an address that would only be reachable via default (e.g., 200.200.200.200) — should exit the VRF
6. **Critical test:** R12 (Customer_B) does NOT have a default route — only Customer_A was given internet
7. Remove the static route on R2 — verify R1's default disappears within BGP timer

### Task 14: Per-Customer Internet Policy

1. Now give Customer_B internet too: `ip route vrf Customer_B 0.0.0.0 0.0.0.0 GigabitEthernet2/0 172.16.26.2 global`
2. Redistribute into BGP under VRF Customer_B
3. Verify: R12 now has a default route
4. Verify: Customer_A and Customer_B both have internet but STILL cannot reach each other
5. This is the SP model: each customer gets their own internet access, fully isolated from other customers
6. Remove both static routes — clean up for next lab

---

## CCIE+ Challenges

### Challenge 1: Central Services with Full Isolation Matrix

1. Build the complete architecture simultaneously:
   - 5 customers (A, B, C, D, E) all fully isolated from each other
   - 1 Shared Services VRF reachable by ALL 5 customers
   - Shared Services can reach ALL customers (bi-directional)
   - NO customer can reach any other customer
2. Design the RT matrix on paper first — document which RTs each VRF exports and imports
3. Implement on all 4 PEs
4. Verify: every customer can ping shared services (100.100.100.1)
5. Verify: shared services can ping every CE loopback
6. Verify: NO cross-customer pings succeed (full isolation maintained)
7. This requires careful RT planning — total of 6 VRFs, ~12 RT values

### Challenge 2: Hub-and-Spoke with Dual Hubs (Redundancy)

1. Customer_A: R1 is primary hub, R9 is secondary hub
2. R19 and R20 are spokes (repurpose from other VRFs for this challenge)
3. Design RT scheme:
   - Spokes export RT-spoke, import RT-hub
   - Primary hub (R1) exports RT-hub, imports RT-spoke
   - Secondary hub (R9) exports RT-hub, imports RT-spoke
4. Verify: spokes reach both hubs
5. Verify: spoke-to-spoke traffic goes via hub
6. Kill primary hub (R1) — verify spokes still reach each other via secondary hub (R9)
7. This is how real SPs do hub redundancy for enterprise customers

### Challenge 3: Carrier's Carrier (CsC)

1. Your SP (AS 64512) provides MPLS backbone to a customer SP
2. The customer SP runs their own MPLS network inside your VRF
3. On the PE-CE link (e.g., R2↔R1): configure labeled BGP (send-label)
   - R2: `neighbor 192.168.12.1 send-label` under VRF Customer_A
   - R1: `neighbor 192.168.12.2 send-label`
4. R1 runs LDP internally (to its own CE routers downstream)
5. Verify: `show ip bgp vpnv4 vrf Customer_A labels` on R2 — labels exchanged with R1
6. Verify: the customer SP's internal labels traverse your backbone transparently
7. Result: three-label stack (your transport + your VPN + customer's label)
8. Note: requires `mpls bgp forwarding` on PE-CE interface — verify this works on IOS 15.2

### Challenge 4: VRF Import-Map with Prefix Filtering

1. Shared services exports RT 64512:999 and advertises 100.100.100.1/32, 100.100.200.1/32, and 100.100.300.1/32
2. Customer_A wants access ONLY to 100.100.100.1/32 (DNS) — not NTP or other services
3. On R2: create an import-map under VRF Customer_A:
   - Match prefix-list allowing only 100.100.100.1/32
   - Match RT 64512:999
   - Only routes matching BOTH conditions get imported
4. Verify: `show ip route vrf Customer_A` on R2 — only 100.100.100.1 appears from shared services
5. Verify: R1 can ping 100.100.100.1 but CANNOT ping 100.100.200.1 (filtered at import)
6. Customer_B can still reach all shared services (no import-map applied to Customer_B)

### Challenge 5: OSPF PE-CE Sham-Link with Backdoor

1. Change both R1↔R2 and R9↔R8 PE-CE to OSPF (area 0)
2. Add a simulated backdoor link between R1 and R9 (direct OSPF adjacency, if interfaces available)
3. Verify: without sham-link, R9 prefers backdoor (intra-area route) over VPN path (external route)
4. Configure sham-link:
   - On R2: VRF loopback (e.g., 2.2.2.100/32 in VRF, advertised via BGP not OSPF)
   - On R8: VRF loopback (e.g., 8.8.8.100/32 in VRF, advertised via BGP not OSPF)
   - `area 0 sham-link 2.2.2.100 8.8.8.100`
5. Verify: R9 now prefers VPN path (sham-link makes it intra-area, same as backdoor but lower cost)
6. Kill MPLS core — verify R9 falls back to backdoor
7. Restore core — verify VPN path wins again

---

## Final Validation

By the end of this lab, your network has:

- [ ] Shared Services VRF reachable by Customer_A and Customer_B (bi-directional)
- [ ] Full customer isolation maintained — no cross-customer traffic possible
- [ ] Hub-and-spoke topology: spoke-to-spoke traffic forced through hub CE
- [ ] Multiple spokes confirmed (at least 2 spokes + 1 hub)
- [ ] Multi-homed CE with dual PE attachment and path preference control
- [ ] AS-PATH prepend providing primary/backup PE selection
- [ ] SOO preventing routing loops on multi-homed sites
- [ ] Extranet: selective one-way prefix sharing between VRFs (single prefix only)
- [ ] Per-VRF internet access via default route injection
- [ ] Customer internet isolation verified (internet access ≠ inter-customer access)
- [ ] (CCIE+) Full 5-customer + shared services isolation matrix
- [ ] (CCIE+) Hub-and-spoke with dual-hub redundancy and failover
- [ ] (CCIE+) Carrier's Carrier with three-label stack
- [ ] (CCIE+) Import-map with prefix filtering for granular route control
- [ ] (CCIE+) OSPF sham-link with backdoor failover
