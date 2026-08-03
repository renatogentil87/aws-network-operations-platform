# Lab 2: MPLS L3VPN — Workbook

**Platform:** GNS3 Local (Cisco 7200)
**Topology:** 20 routers — 4 PEs (R2, R8, R17, R18), 9 P routers, CEs in multiple VRFs

**End Goal:** A multi-customer MPLS VPN network with 5 isolated customers, mixed PE-CE protocols, route reflectors for vpnv4, and inter-AS connectivity. By the end, you have a production-like SP VPN service.

---

## Section 1: Build the Base VPN Service

### Task 1: First Customer — Two Sites

1. Configure VRF "Customer_A" on R2 and R8 with RD 64512:100 and RT 64512:100 - done
2. Assign R2 Fa0/0 (toward R1) and R8 Gi1/0 (toward R9) into VRF Customer_A - done
3. Configure eBGP between R1 (AS 65001) and R2 (AS 64512) under VRF Customer_A - done
4. Configure eBGP between R9 (AS 65001) and R8 (AS 64512) under VRF Customer_A - done
5. Configure MP-BGP vpnv4 peering between R2 and R8 using loopbacks - done
6. Make R1 advertise its loopbacks (1.1.1.1, 11.11.11.11) via `redistribute connected` - done
7. Make R9 advertise its loopbacks (9.9.9.9, 99.99.99.99) via `redistribute connected` - done
8. Verify: R1 can ping R9 loopback 9.9.9.9 - done
9. Verify: R9 can ping R1 loopback 1.1.1.1 - done
10. Verify: traceroute from R1 to 9.9.9.9 shows 2 MPLS labels in the core - done

### Task 2: Same-AS CEs — Fix the Loop Problem

1. R1 and R9 are both AS 65001 — verify R1 rejects R9's routes (show ip bgp on R1 — routes missing) - done
2. Enable as-override on R2 toward R1 - done
3. Enable as-override on R8 toward R9 - done
4. Verify: R1 now has R9's routes in its BGP table - done
5. Verify: bidirectional ping works - done

### Task 3: Second Customer — Prove Isolation

1. Configure VRF "Customer_B" on R2 (RD 64512:200, RT 64512:200) and R8 (same) - done
2. Assign R2 Fa3/0 (toward R12) into VRF Customer_B - done
3. Assign R8 Fa4/0 (toward R11) into VRF Customer_B - done
4. Configure eBGP: R12 (AS 65012) ↔ R2, R11 (AS 65011) ↔ R8 - done
5. Make R12 and R11 advertise their loopbacks - done
6. Verify: R12 can ping R11 (same VPN, different sites) - done 
7. Verify: R12 CANNOT ping R1 or R9 (different VPN) - done
8. Verify: R1 CANNOT ping R11 (different VPN) - done
9. Verify: `show ip route vrf Customer_B` has zero Customer_A routes - done

### Task 4: Scale to Four PEs

1. Configure vpnv4 peering from R17 to R2 and from R18 to R2 (full mesh between all PEs) - done
2. Configure VRF "Customer_D" on R17 (RD 64512:400, RT 64512:400) - done
3. Configure VRF "Customer_E" on R18 (RD 64512:500, RT 64512:500) - done
4. Configure eBGP: R19 (AS 65019) ↔ R17, R20 (AS 65020) ↔ R18 - done
5. Verify: R19 can only reach its own VRF routes - done
6. Verify: R20 can only reach its own VRF routes - done
7. Verify: no VRF can reach any other VRF (total of 5 customers, all isolated) - done
8. Count total vpnv4 sessions — how many iBGP sessions exist? (N*(N-1)/2 = 6) - done

---

## Section 2: Mixed PE-CE Protocols

### Task 5: OSPF PE-CE (R9 Site)

1. Remove eBGP between R9 and R8 under VRF Customer_A - done
2. Configure OSPF process 2 on R8 under VRF Customer_A (area 0) - done
3. Configure OSPF on R9 to peer with R8 (area 0) - done
4. On R8: redistribute OSPF 2 into BGP (under VRF), and redistribute BGP into OSPF 2 - done
5. Verify: R1 (BGP site) can ping R9 (OSPF site) 9.9.9.9 - done
6. Verify: R9 learns R1's routes as OSPF external (O E2) via `show ip route` - done
7. On R9: `show ip ospf database external 1.1.1.1` — confirm DN bit (Downward) is set - done
8. Explain: why does the DN bit matter if a third PE were connected to R9? - done

### Task 6: Static PE-CE (R20 Site)

1. Remove eBGP between R20 and R18 - done 
2. On R18: configure static route in VRF Customer_E pointing to R20's loopback via R20's PE-CE IP - done
3. Redistribute static into BGP under VRF Customer_E - done
4. On R20: configure static default route pointing to R18 - done
5. Verify: R20 can reach its PE loopback (18.18.18.18 in VRF) - done
6. This demonstrates the simplest PE-CE — no routing protocol, just static - done

---

## Section 3: Verify the Data Plane

### Task 7: Label Stack Analysis

1. From R1, traceroute to R9 (9.9.9.9) — identify transport label (top, changes per hop) and VPN label (bottom, constant) - done
2. On R2: `show ip cef vrf Customer_A 9.9.9.9` — note both labels pushed - done
3. On R3 (P router): `show mpls forwarding-table` — find the entry for transport label. Verify R3 only swaps transport, never touches VPN label - done
4. On R8: `show ip bgp vpnv4 vrf Customer_A 9.9.9.9` — confirm `mpls labels in/out 32/nolabel` - done
5. Explain: why is outgoing label "nolabel" on R8? (Because next-hop is directly connected CE — no MPLS needed) - done

### Task 8: What Happens When VPN Label is Wrong?

1. On R8: note the current VPN label for 9.9.9.9 (e.g., 32) - done
2. Clear BGP between R2 and R8: `clear ip bgp 8.8.8.8` - done
3. After session re-establishes, check: did the VPN label change? - done
4. If it changed, what happened to traffic during the reset? (Brief blackhole until new label propagates) - done
5. This proves: VPN labels are dynamically assigned and can change after BGP reset - done

---

## Section 4: Route Reflectors (Scale the Control Plane)

### Task 9: Replace Full-Mesh with Route Reflectors

1. Current state: 6 iBGP vpnv4 sessions (4 PEs, full mesh). This doesn't scale. - done
2. Designate R3 as Route Reflector. Configure all PEs as RR clients under address-family vpnv4. - done
3. Designate R7 as second Route Reflector (redundancy). Same client config. - done
4. On all PEs: remove direct vpnv4 peering to other PEs. Keep only sessions to R3 and R7. - done
5. Verify: `show ip bgp vpnv4 all summary` on R2 — only 2 peers (R3, R7), not 3 - done
6. Verify: R1 can still ping R9 (routes reflected via RR) - done
7. Verify: R19 can still reach its own VRF (routes reflected via RR) - done
8. Shut R3 — verify everything still works via R7 - done
9. Bring R3 back — verify both RRs have identical vpnv4 tables - done


### Task 10: Verify RR Attributes

1. On R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — look for ORIGINATOR_ID and CLUSTER_LIST - done
2. ORIGINATOR_ID should be R2 (2.2.2.2) — the PE that originated the route - done
3. CLUSTER_LIST should show R3 or R7's cluster-id — proves the route was reflected - done
4. These attributes prevent routing loops between RRs - done

---

## Section 5: CCIE+ Challenges

### Challenge 1: OSPF Sham-Link

**Prerequisite:** Change R1's PE-CE from eBGP to OSPF (same as R9). Both CEs now run OSPF with their PE. - done 

1. Add a backdoor OSPF link between R1 and R9 (connect R1 Gi2/0 to R9 Gi2/0, same subnet, OSPF area 0) - done
2. Verify: R9 now prefers R1's routes via the backdoor (intra-area) over the VPN path (external) - done
3. Traceroute from R9 to 1.1.1.1 — traffic goes directly via backdoor, NOT through MPLS core - done
4. Configure a sham-link between R2 and R8 (source/dest are VRF loopbacks advertised via BGP, not OSPF) - done
5. Verify: R9 now prefers the VPN path again (sham-link makes it appear as intra-area) - done
6. Shut the MPLS core link (simulate VPN failure) — verify R9 falls back to backdoor - done
7. Bring core back — verify traffic returns to VPN path - done

### Challenge 2: Per-Prefix Label Mode

1. On R8: `show mpls forwarding-table vrf Customer_A` — note how many labels are assigned (default: one per VRF or per-CE) - done
2. Change to per-prefix: `mpls label mode vrf Customer_A protocol bgp-vpnv4 per-prefix` - done
3. Clear BGP to force label re-assignment - done
4. Verify: `show mpls forwarding-table vrf Customer_A` — each prefix now has a unique label - done
5. On R2: `show ip bgp vpnv4 vrf Customer_A` — each route from R8 has a different label - done
6. Revert to default and compare - done
7. Research: when is per-prefix needed? (Answer: when you need per-prefix TE or per-prefix accounting) - done

### Challenge 3: RT-Constrained Distribution (RFC 4684)

**Prerequisite:** RRs from Task 9 must be in place.

1. On R3 (RR): enable RT-constraint: `address-family rtfilter unicast` + activate all PE neighbors
2. On each PE: enable RT-constraint toward the RR
3. Verify: R17 (only has Customer_D, RT 64512:400) does NOT receive Customer_A routes (RT 64512:100)
4. On R17: `show ip bgp vpnv4 all` — should only show Customer_D prefixes
5. Add Customer_A VRF to R17 (import RT 64512:100) — verify R17 now receives Customer_A routes
6. Remove it — verify routes disappear again
7. Proves: RR only sends what each PE actually needs

### Challenge 4: Inter-AS Option A (Back-to-Back VRF)

1. Split the topology: AS 64512 (R2, R3, R4, R5, R6) and AS 64513 (R7, R8, R13-R18)
2. R6 and R7 are ASBRs — remove their iBGP peering to the other AS
3. On R6 (ASBR): create VRF Customer_A, assign the interface toward R7 into the VRF
4. On R7 (ASBR): create VRF Customer_A, assign the interface toward R6 into the VRF
5. Configure eBGP between R6 and R7 under VRF Customer_A (AS 64512 ↔ AS 64513)
6. On R6: vpnv4 peering with R2 (within AS 64512). On R7: vpnv4 peering with R8 (within AS 64513)
7. Verify: R1 (behind R2 in AS 64512) can reach R9 (behind R8 in AS 64513)
8. Verify: traceroute shows the ASBR hop (VPN traffic is de-encapsulated and re-encapsulated at ASBRs)

### Challenge 5: Internet Access for VPN Customers

1. On R2: add a loopback in the global table (200.200.200.200) to simulate an internet router
2. Redistribute this into BGP under VRF Customer_A as a default route:
   - `ip route vrf Customer_A 0.0.0.0 0.0.0.0 200.200.200.200 global`
   - Under BGP VRF: `redistribute static`
3. Verify: R1 receives a default route (0.0.0.0/0) from R2 via eBGP
4. Verify: R1 can ping 200.200.200.200 (simulated internet)
5. Verify: only Customer_A gets the default — Customer_B, D, E do not
6. Remove the route — verify default disappears from R1

### Challenge 6: Export-Map for Selective RT Tagging

1. Customer_A has loopback routes (1.1.1.1, 11.11.11.11) and connected routes (192.168.12.0/30)
2. On R2: create an export-map that tags loopback routes with an additional RT 64512:999
3. Connected routes keep only RT 64512:100 (no extra tag)
4. On R8: `show ip bgp vpnv4 vrf Customer_A` — verify loopback routes have two RTs, connected has one
5. Create a VRF "Monitor" on R8 that only imports RT 64512:999
6. Verify: Monitor VRF only has the loopback routes (not connected)
7. Use case: selective route leaking — shared services only sees specific prefixes

---

## Final Validation

By the end of this lab, your network has:

- [ ] 5 customers fully isolated (Customer_A, B, C, D, E)
- [ ] 4 PEs (R2, R8, R17, R18) with vpnv4 peering via Route Reflectors (R3, R7)
- [ ] Mixed PE-CE: eBGP (R1, R12, R11, R19), OSPF (R9), Static (R20)
- [ ] AS-override for same-AS CEs
- [ ] DN bit preventing OSPF loops on OSPF PE-CE sites
- [ ] Full label stack understanding (transport + VPN, verified hop-by-hop)
- [ ] RR redundancy (one RR down, VPN still works)
- [ ] (CCIE+) Sham-link with OSPF backdoor
- [ ] (CCIE+) Per-prefix label mode understood
- [ ] (CCIE+) RT-constraint reducing unnecessary route distribution
- [ ] (CCIE+) Inter-AS Option A between two ASes
- [ ] (CCIE+) Internet access via VRF route leaking
- [ ] (CCIE+) Export-map for selective RT tagging
