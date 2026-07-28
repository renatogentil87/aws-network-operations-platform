# Lab 6: Advanced L3VPN Scenarios — Workbook

**Platform:** GNS3 Local (Cisco 7200)
**Prerequisite:** Lab 2 complete (basic L3VPN working between all customers)

---

## Task 1: Shared Services (Inter-VRF Route Leaking)

1. Create VRF "Shared_Services" on R2 with RD 64512:999
2. Set RT export 64512:999
3. Set RT import 64512:999, 64512:100 (Customer_A), 64512:200 (Customer_B)
4. On VRF Customer_A (R2): add `route-target import 64512:999` (so Customer_A can reach shared services)
5. On VRF Customer_B (R2): add `route-target import 64512:999` (so Customer_B can reach shared services)
6. Create a loopback in VRF Shared_Services (e.g., 100.100.100.100) to simulate a shared server
7. Verify: R1 (Customer_A) can ping 100.100.100.100
8. Verify: R12 (Customer_B) can ping 100.100.100.100
9. Verify: R1 still CANNOT ping R12 (customers remain isolated from each other)
10. Verify: `show ip route vrf Customer_A` shows the shared services route
11. Verify: `show ip route vrf Customer_B` shows the shared services route

---

## Task 2: Hub-and-Spoke VPN

1. Designate R1 as the hub site for Customer_A
2. On R2 (hub PE): VRF Customer_A exports RT 64512:100, imports RT 64512:101
3. On R8 (spoke PE): VRF Customer_A exports RT 64512:101, imports RT 64512:100
4. If you have a third site (e.g., R17 as spoke PE): same spoke RT configuration
5. Verify: R9 (spoke) can ping R1 (hub)
6. Verify: R1 (hub) can ping R9 (spoke)
7. Verify: R9 CANNOT ping another spoke directly (traffic must go through hub)
8. Traceroute from R9 to another spoke — confirm it goes via R1 (hub)
9. Verify: all spoke-to-spoke traffic transits through the hub CE

---

## Task 3: Multi-homed CE (Dual PE Attachment)

1. Connect R1 to BOTH R2 and R17 (two PE-CE links in the same VRF Customer_A)
2. Configure eBGP between R1 and R17 under VRF Customer_A
3. R1 advertises the same loopbacks to both R2 and R8 via BGP
4. Verify: R9 has two paths to reach R1 (via R2 and via R17)
5. Check on R8: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` — should show 2 paths
6. Shut R1's link to R2 — verify traffic fails over to R17 path
7. Bring link back — verify traffic returns to preferred path
8. Use AS-PATH prepend on R1 toward R17 to make R2 the preferred path
9. Verify: R9 prefers path via R2 (shorter AS-PATH)

---

## Task 4: Site of Origin (SOO) — Loop Prevention

1. Using the multi-homed setup from Task 3 (R1 connected to R2 and R17)
2. On R2 under VRF Customer_A: set SOO for R1's routes: `set extcommunity soo 64512:1`
3. On R17 under VRF Customer_A: set same SOO: `set extcommunity soo 64512:1`
4. Verify: R1's routes advertised to R2 do NOT come back to R1 via R17
5. Verify: R1's routes advertised to R17 do NOT come back to R1 via R2
6. Verify: R9 still has reachability to R1 (SOO doesn't break forwarding)
7. Verify: `show ip bgp vpnv4 vrf Customer_A 1.1.1.1` shows SOO extended community attached

---

## Task 5: Internet Access for VPN Customer

1. On R2, create a static route in VRF Customer_A: `ip route vrf Customer_A 0.0.0.0 0.0.0.0 <next-hop>` (use a global table route or null interface for simulation)
2. Redistribute that static route into BGP under VRF Customer_A
3. Verify: R1 receives a default route (0.0.0.0/0) via BGP from R2
4. Verify: `show ip route` on R1 shows the default route
5. Verify: only Customer_A receives the default route — Customer_B does not
6. Remove the default route — verify R1 no longer has it

---

## Task 6: Different PE-CE Protocols Per Site

1. Site 1 (R1 ↔ R2): keep eBGP as PE-CE protocol
2. Site 2 (R9 ↔ R8): change to OSPF as PE-CE protocol
   - Remove eBGP config between R9 and R8
   - Configure OSPF process under VRF Customer_A on R8
   - Configure OSPF on R9 to peer with R8
   - Redistribute OSPF into BGP and BGP into OSPF on R8
3. Verify: R1 (BGP site) can still ping R9 (OSPF site)
4. Verify: R9 learns R1's routes via OSPF (redistributed by R8)
5. On R9: `show ip route` — R1's loopbacks should appear as OSPF external routes (O E2)
6. Check for DN-bit (down bit) on R9's OSPF database to prevent loops

---

## Task 7: Extranet VPN (Selective Route Sharing)

1. Customer_A (RT 64512:100) wants to share ONE specific prefix with Customer_B (RT 64512:200)
2. On the PE: create a route-map that matches the specific prefix and sets RT 64512:200
3. Apply as export-map under VRF Customer_A
4. Verify: Customer_B receives ONLY that specific prefix from Customer_A
5. Verify: Customer_B does NOT receive all of Customer_A's routes
6. Verify: Customer_A still cannot see Customer_B's routes (one-way sharing)

---

## Validation Checklist

- [ ] Shared services reachable from both customers
- [ ] Customers remain isolated from each other despite shared services
- [ ] Hub-and-spoke: spokes communicate only through hub
- [ ] Multi-homed CE: failover works, preferred path works
- [ ] SOO prevents routing loops on multi-homed sites
- [ ] Default route injected into specific VRF only
- [ ] Mixed PE-CE protocols (BGP + OSPF) work in same VPN
- [ ] Extranet: selective prefix sharing between VRFs

---

## CCIE+ Challenge Tasks

### Challenge 1: Central Services VPN with SOO and RT Constraints
- 5 customers, 1 shared services VRF
- Each customer can reach shared services but NOT each other
- Shared services can reach ALL customers
- One customer (Customer_A) is multi-homed to 2 PEs — configure SOO to prevent loops
- Verify the entire setup works simultaneously — no cross-contamination

### Challenge 2: OSPF Backdoor Link + Sham-Link + DN Bit
- Two CE sites run OSPF PE-CE with the same PE pair
- Add a backdoor OSPF link between the two CEs (direct, bypassing MPLS)
- Without sham-link: OSPF prefers backdoor (intra-area > inter-area)
- Configure sham-link to make VPN path competitive
- Verify: normal traffic goes through MPLS, backdoor only used as backup
- Kill the VPN path — verify backdoor activates
- Examine DN bit behaviour when routes loop back from BGP to OSPF

### Challenge 3: Complex RT Topology — Full Mesh + Hub-Spoke Combined
- Customer_A: 3 sites, full mesh (all sites talk to all)
- Customer_B: 4 sites, hub-and-spoke (hub at R2, spokes at R8, R17, R18)
- Both customers share the same MPLS core
- Design the RT import/export for BOTH topologies simultaneously
- Verify: Customer_A full mesh works, Customer_B hub-spoke works, no leaking between A and B

### Challenge 4: VRF Route Leaking with Prefix Filtering
- Shared services VRF exports RT 64512:999
- Customer_A imports 64512:999 BUT only accepts prefix 100.100.100.0/24 (not everything)
- Use ip prefix-list + import-map to filter at VRF import
- Verify: only the allowed prefix leaks into Customer_A
- Verify: other shared services routes do NOT leak

### Challenge 5: Carrier's Carrier (CsC)
- Your MPLS network is the backbone carrier
- One of your "customers" is actually another SP running their own MPLS
- The customer SP runs LDP/IGP within their VRF
- Configure labeled BGP (SAFI 4) on the PE-CE link
- Verify: customer SP's internal labels are carried transparently through your backbone
- Verify: customer SP's own VPN customers have end-to-end connectivity
