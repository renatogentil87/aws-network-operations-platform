# Lab 2: MPLS L3VPN — Workbook

**Platform:** GNS3 Local (Cisco 7200)
**Topology:** 20 routers — 4 PEs (R2, R8, R17, R18), 9 P routers, CEs in multiple VRFs

---

## Task 1: Basic L3VPN Connectivity

1. Configure VRF "Customer_A" on R2 and R8 with RD 64512:100 and RT 64512:100 - done
2. Assign R2 Fa0/0 (toward R1) and R8 Gi1/0 (toward R9) into VRF Customer_A - done
3. Configure eBGP between R1 (AS 65001) and R2 (AS 64512) under VRF Customer_A - done
4. Configure eBGP between R9 (AS 65001) and R8 (AS 64512) under VRF Customer_A - done
5. Configure MP-BGP vpnv4 peering between R2 and R8 using loopbacks - done
6. Make R1 advertise its loopbacks (1.1.1.1, 11.11.11.11) into BGP - done
7. Make R9 advertise its loopbacks (9.9.9.9, 99.99.99.99) into BGP - done
8. Verify: R1 can ping R9 loopback 9.9.9.9 - done
9. Verify: R9 can ping R1 loopback 1.1.1.1 - done
10. Verify: traceroute from R1 to 9.9.9.9 shows 2 MPLS labels in the core - done

---

## Task 2: Second Customer — Isolation

1. Configure VRF "Customer_B" on R2 with RD 64512:200 and RT 64512:200 - done
2. Connect R12 (CE) to R2 and assign the PE-CE interface into VRF Customer_B - done 
3. Configure eBGP between R12 (AS 65012) and R2 (AS 64512) under VRF Customer_B
4. Make R12 advertise its loopback (12.12.12.12) into BGP - done
5. Verify: R12 can ping R2's VRF Customer_B loopback - done 
6. Verify: R12 CANNOT ping R1 (Customer_A) — complete isolation - done
7. Verify: R12 CANNOT ping R9 (Customer_A) — complete isolation - done
8. Verify: `show ip route vrf Customer_B` has no Customer_A routes - done
9. Verify: `show ip route vrf Customer_A` has no Customer_B routes - done 

---

## Task 3: Extend Customer_B to a Second Site

1. Configure VRF "Customer_B" on R8 with same RD and RT as R2's Customer_B - done
2. Connect R11 (CE) to R8 and assign the PE-CE interface into VRF Customer_B - done
3. Configure eBGP between R11 (AS 65011) and R8 (AS 64512) under VRF Customer_B - done
4. Make R11 advertise its loopback (11.11.11.11) into BGP - done
5. Verify: R12 can ping R11 loopback 11.11.11.11 - done
6. Verify: R11 can ping R12 loopback 12.12.12.12 - done
7. Verify: R11 still CANNOT ping R1 or R9 (different VRF) - done

---

## Task 4: Third Customer with PEs R17 and R18

1. Configure VRF "Customer_D" on R17 with RD 64512:400 and RT 64512:400
2. Configure VRF "Customer_E" on R18 with RD 64512:500 and RT 64512:500
3. Connect R19 (CE, AS 65019) to R17 under VRF Customer_D - done
4. Connect R20 (CE, AS 65020) to R18 under VRF Customer_E - done
5. Configure vpnv4 peering between R17 and R2 (via loopbacks) - done
6. Configure vpnv4 peering between R18 and R2 (via loopbacks) - done
7. Verify: R19 can reach its own VRF routes only - done
8. Verify: R20 can reach its own VRF routes only - done 
9. Verify: R19 CANNOT ping R20 (different VRFs) - done
10. Verify: R19 CANNOT ping R1 or R9 (different VRFs) - done

---

## Task 5: AS-Override

1. Both R1 and R9 are in AS 65001 — routes from R9 contain AS 65001 in the path - done
2. Without as-override, verify R1 rejects R9's routes (BGP loop prevention) - done
3. Enable as-override on R2 toward R1: `neighbor x.x.x.x as-override` - done
4. Enable as-override on R8 toward R9: `neighbor x.x.x.x as-override` -- done
5. Verify: R1 now accepts R9's routes - done
6. Verify: R1 can ping R9 loopbacks successfully - done

---

## Task 6: PE-CE with OSPF (Mixed Protocol)

1. Remove eBGP between R9 and R8 under VRF Customer_A
2. Configure OSPF process 2 on R8 under VRF Customer_A
3. Configure OSPF on R9 to peer with R8
4. Redistribute OSPF into BGP and BGP into OSPF on R8 (under VRF)
5. Verify: R1 (BGP site) can still ping R9 (OSPF site) loopback 9.9.9.9
6. Verify: R9 learns R1's routes via OSPF (redistributed from BGP into OSPF by R8)
7. Check the OSPF down-bit on R9: `show ip ospf database` — verify DN bit prevents loops

---

## Task 7: Verify Label Stack

1. From R1, traceroute to R9 loopback 9.9.9.9
2. Identify the two labels: transport label (top) and VPN label (bottom)
3. On R2: `show ip cef vrf Customer_A 9.9.9.9` — note both labels
4. On a P router in the path: `show mpls forwarding-table` — verify it only sees/swaps the transport label
5. On R8: `show ip bgp vpnv4 vrf Customer_A 9.9.9.9` — note the VPN label assigned
6. Confirm: transport label changes at each hop (swap), VPN label stays the same end-to-end

---

## Validation Checklist

- [ ] Customer_A: R1 ↔ R9 full reachability
- [ ] Customer_B: R12 ↔ R11 full reachability
- [ ] Customer_D: R19 isolated
- [ ] Customer_E: R20 isolated
- [ ] No cross-VRF leaking between any customers
- [ ] Two labels visible in traceroute through the core
- [ ] vpnv4 sessions established between all PE pairs
- [ ] as-override working (same AS on both CEs)
- [ ] OSPF PE-CE working alongside BGP PE-CE

---

## CCIE+ Challenge Tasks

### Challenge 1: OSPF Sham-Link
- R1 and R9 are in the same VPN but also have a backdoor OSPF link between them (simulate with a shared segment)
- Without a sham-link, OSPF prefers the backdoor over the MPLS VPN path
- Configure a sham-link between R2 and R8 to make the VPN path preferred
- Verify: traffic goes through the MPLS core, not the backdoor
- Verify: if the VPN path fails, traffic falls back to the backdoor

### Challenge 2: RT Rewrite with Export Maps
- Customer_A has two tiers of routes: "gold" prefixes (loopbacks) and "silver" prefixes (connected)
- Configure an export-map on R2 that tags gold prefixes with RT 64512:100 and silver with RT 64512:150
- On R8: import both RTs into Customer_A VRF but apply different local-pref (gold = 200, silver = 100)
- Verify: R9 prefers gold routes over silver if both paths exist

### Challenge 3: Per-VRF Label Mode
- Default: PE assigns one label per VRF (all routes in the VRF share a label)
- Change to per-prefix label mode: `mpls label mode vrf Customer_A protocol bgp-vpnv4 per-prefix`
- Verify: each prefix in the VRF gets a unique VPN label
- Compare LFIB before and after — count the labels
- When would you use per-prefix vs per-VRF? (Hint: traffic engineering at the VPN layer)

### Challenge 4: VPNv4 Route Filtering on Route Reflector
- On the RR (R3): configure an RT-constrained distribution
- Only reflect Customer_A routes to PEs that have Customer_A configured
- Only reflect Customer_B routes to PEs that have Customer_B configured
- Verify: R17 (only has Customer_D) does NOT receive Customer_A or B routes
- Proves: RR doesn't waste memory/bandwidth sending irrelevant routes

### Challenge 5: OSPF PE-CE with Multiple Areas
- R9 runs OSPF with R8 (PE-CE) in area 0
- Add a second OSPF area (area 1) behind R9 with a new loopback
- Verify: area 1 routes appear as inter-area (O IA) on R1
- Check OSPF domain-id handling — what happens if R2 and R8 have different domain-ids?
- What happens if R1 also runs OSPF (not BGP) — does the DN bit prevent loops?

### Challenge 6: Multi-AS VPN (Inter-AS Option A, B, C)
- Split your topology into two ASes: AS 64512 (R2, R3, R4, R5, R6) and AS 64513 (R7, R8, R17, R18)
- R6 and R7 are ASBRs connecting the two ASes
- Implement Inter-AS Option A: back-to-back VRF on the ASBRs (simplest)
- Verify: R1 (AS 64512) can reach R9 (AS 64513)
- Stretch: implement Option B (vpnv4 exchange between ASBRs with next-hop-self)
- Stretch: implement Option C (multihop eBGP for vpnv4 + labeled unicast for transport)
