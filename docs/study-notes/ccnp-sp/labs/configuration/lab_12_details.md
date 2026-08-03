# Lab 12: IPv6 over MPLS (6PE/6VPE) — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers. Core remains IPv4+MPLS. CEs gain IPv6.
**Prerequisite:** Lab 2 complete (L3VPN working), MPLS LDP operational

**End Goal:** IPv6 customer connectivity delivered over your existing IPv4 MPLS core — without upgrading P routers to dual-stack. By the end, you have both 6PE (IPv6 in global table) and 6VPE (IPv6 inside VRFs), proving the SP can offer IPv6 services while keeping the core simple. This is how real SPs deployed IPv6 without forklift-upgrading their entire infrastructure.

---

## Section 1: 6PE — IPv6 Over IPv4 MPLS Core (Global Table)

### Task 1: Enable IPv6 on PE-CE Interfaces

1. On R2: enable IPv6 on the CE-facing interface (Fa0/0 toward R1):
   - `ipv6 address 2001:DB8:12::2/64`
   - `ipv6 unicast-routing` (global command)
2. On R1: enable IPv6:
   - `ipv6 unicast-routing`
   - `ipv6 address 2001:DB8:12::1/64` (on Fa0/0 toward R2)
   - Add IPv6 loopback: `interface Loopback0` → `ipv6 address 2001:DB8:1::1/128`
3. On R8: enable IPv6 on CE-facing interface (Gi1/0 toward R9):
   - `ipv6 address 2001:DB8:89::8/64`
4. On R9: enable IPv6:
   - `ipv6 unicast-routing`
   - `ipv6 address 2001:DB8:89::9/64`
   - IPv6 loopback: `ipv6 address 2001:DB8:9::9/128`
5. Verify: R1 can ping R2 IPv6 (2001:DB8:12::2) — local link works
6. Verify: R9 can ping R8 IPv6 (2001:DB8:89::8) — local link works
7. **Do NOT enable IPv6 on core P routers** — the core stays pure IPv4+MPLS

### Task 2: Configure 6PE (IPv6 BGP with IPv4 Next-Hop)

1. On R2: under `router bgp 64512`:
   - `address-family ipv6 unicast`
   - `neighbor 8.8.8.8 activate` (iBGP to R8 for IPv6, using IPv4 loopback as peer)
   - `neighbor 8.8.8.8 send-label` (CRITICAL — tells R8 to use MPLS label for IPv6)
2. On R8: under `router bgp 64512`:
   - `address-family ipv6 unicast`
   - `neighbor 2.2.2.2 activate`
   - `neighbor 2.2.2.2 send-label`
3. On R2: advertise R1's IPv6 prefix:
   - `address-family ipv6 unicast`
   - `network 2001:DB8:1::1/128` (R1's loopback)
   - `network 2001:DB8:12::/64` (PE-CE link)
4. On R8: advertise R9's IPv6 prefix:
   - `network 2001:DB8:9::9/128`
   - `network 2001:DB8:89::/64`
5. Verify: `show bgp ipv6 unicast summary` on R2 — session to R8 established

### Task 3: Verify 6PE Forwarding

1. On R2: `show bgp ipv6 unicast 2001:DB8:9::9/128` — note:
   - Next-hop is 8.8.8.8 (IPv4 address!)
   - Label: a specific label value (this is the 6PE label)
2. On R8: `show bgp ipv6 unicast 2001:DB8:1::1/128` — same structure, label present
3. The forwarding path: R2 pushes TWO labels:
   - Transport label (LDP, to reach 8.8.8.8)
   - 6PE label (tells R8 this is an IPv6 packet for the global table)
4. P routers in the core NEVER SEE IPv6 — they just swap transport labels as always
5. Verify: R1 can ping R9 IPv6 loopback (2001:DB8:9::9):
   - `ping ipv6 2001:DB8:9::9 source 2001:DB8:1::1`
6. If ping fails: check that R1 has a route to R9's prefix and next-hop resolves

### Task 4: Add IPv6 Routes from CEs via eBGP

1. On R1: configure eBGP to R2 for IPv6:
   - `router bgp 65001`
   - `address-family ipv6 unicast`
   - `neighbor 2001:DB8:12::2 activate`
   - `network 2001:DB8:1::1/128`
2. On R2: accept IPv6 routes from R1:
   - `address-family ipv6 unicast`
   - `neighbor 2001:DB8:12::1 remote-as 65001`
   - `neighbor 2001:DB8:12::1 activate`
3. On R9: similar eBGP to R8 for IPv6
4. On R8: accept IPv6 routes from R9
5. Verify: R2 learns R1's IPv6 prefix via eBGP, advertises to R8 via 6PE iBGP
6. Verify: R9 can ping R1's IPv6 loopback end-to-end
7. Traceroute: `traceroute ipv6 2001:DB8:1::1 source 2001:DB8:9::9` — observe MPLS labels in core (if TTL propagation is on)

---

## Section 2: 6VPE — IPv6 VPN over MPLS

### Task 5: Create IPv6 VRF (VRF with IPv6 Address Family)

1. On R2: upgrade VRF to support IPv6 (requires VRF definition update):
   - `vrf definition Customer_A` (new-style VRF, replaces `ip vrf`)
   - `rd 64512:100`
   - `address-family ipv4`
   - `route-target export 64512:100`
   - `route-target import 64512:100`
   - `address-family ipv6`
   - `route-target export 64512:100`
   - `route-target import 64512:100`
2. **⚠️ Migration note:** moving from `ip vrf` to `vrf definition` may require re-applying VRF to interfaces. Plan carefully.
3. On R2: assign IPv6 address on VRF interface toward R1:
   - `interface FastEthernet0/0`
   - `vrf forwarding Customer_A` (if not already)
   - `ipv6 address 2001:DB8:A:12::2/64`
4. On R1: `ipv6 address 2001:DB8:A:12::1/64` on Fa0/0
5. On R8: same VRF upgrade and IPv6 addressing on Gi1/0 toward R9
6. On R9: `ipv6 address 2001:DB8:A:89::9/64`
7. Verify: R1 can ping R2's VRF IPv6 (2001:DB8:A:12::2) — link-level works

### Task 6: Configure VPNv6 BGP (6VPE)

1. On R2: under `router bgp 64512`:
   - `address-family vpnv6 unicast`
   - `neighbor 8.8.8.8 activate`
   - `neighbor 8.8.8.8 send-community both`
2. On R8: mirror config:
   - `address-family vpnv6 unicast`
   - `neighbor 2.2.2.2 activate`
   - `neighbor 2.2.2.2 send-community both`
3. On R2: under `address-family ipv6 vrf Customer_A`:
   - `neighbor 2001:DB8:A:12::1 remote-as 65001`
   - `neighbor 2001:DB8:A:12::1 activate`
4. On R1: configure eBGP to R2 for IPv6:
   - `router bgp 65001`
   - `address-family ipv6 unicast`
   - `neighbor 2001:DB8:A:12::2 remote-as 64512`
   - `neighbor 2001:DB8:A:12::2 activate`
   - `network 2001:DB8:1::1/128` (advertise loopback)
5. On R8/R9: mirror configuration
6. Verify: `show bgp vpnv6 unicast all` on R2 — R1's IPv6 prefix with RD 64512:100 and RT 64512:100

### Task 7: Verify End-to-End IPv6 VPN

1. On R2: `show bgp vpnv6 unicast vrf Customer_A 2001:DB8:9::9/128` — route from R8 present with label
2. On R1: `ping ipv6 2001:DB8:9::9 source 2001:DB8:1::1` — end-to-end IPv6 VPN connectivity
3. Verify label stack: three labels total:
   - Transport label (LDP — reach R8)
   - VPN label (6VPE — identifies VRF on R8)
   - (Same concept as IPv4 L3VPN, just carrying IPv6 payload)
4. On R3 (P router): `show mpls forwarding-table` — P router still only sees/swaps transport label. No IPv6 awareness needed.
5. **Key achievement:** IPv6 VPN service delivered over pure IPv4 core. Zero changes to P routers.

---

## Section 3: Dual-Stack VPN — IPv4 and IPv6 in Same VRF

### Task 8: Both Protocols in One VRF

1. Current state: VRF Customer_A on R2 has both `address-family ipv4` and `address-family ipv6`
2. R1 should have both IPv4 (192.168.12.1) and IPv6 (2001:DB8:A:12::1) on the same interface toward R2
3. R1 runs eBGP with R2 for BOTH address families:
   - IPv4 VPN: existing from Lab 2
   - IPv6 VPN: configured in Task 6
4. Verify: R1 can reach R9 via IPv4 (ping 9.9.9.9) AND IPv6 (ping ipv6 2001:DB8:9::9)
5. Both use the same MPLS core, same transport labels — only the VPN label differs
6. Verify: `show ip route vrf Customer_A` has IPv4 routes
7. Verify: `show ipv6 route vrf Customer_A` has IPv6 routes
8. **SP model:** single VRF provides dual-stack service to customer — one contract, both protocols

### Task 9: IPv6-Only Customer on IPv4 MPLS Core

1. Create a new VRF "Customer_IPv6" on R2 and R8:
   - `vrf definition Customer_IPv6`
   - `rd 64512:600`
   - `address-family ipv6` (NO ipv4 address-family — pure IPv6 VRF)
   - `route-target export 64512:600`
   - `route-target import 64512:600`
2. Assign an interface to this VRF (use an available sub-interface)
3. Configure BGP vpnv6 for this VRF
4. Verify: IPv6-only customer traffic traverses the IPv4 MPLS core
5. Verify: no IPv4 addresses needed on the customer-facing interfaces (link-local only for BGP if desired)
6. **Proves:** IPv4 MPLS core transparently carries IPv6-only customers

---

## Section 4: 6PE/6VPE with Route Reflectors

### Task 10: VPNv6 via Route Reflectors

1. On R3 (RR): enable vpnv6 address-family:
   - `address-family vpnv6 unicast`
   - `neighbor <all-PEs> activate`
   - `neighbor <all-PEs> route-reflector-client`
2. On R7 (RR): same configuration
3. On PEs: remove direct vpnv6 peering to other PEs. Peer only with RRs.
4. Verify: `show bgp vpnv6 unicast all summary` on R2 — peers with R3 and R7 only
5. Verify: R1 can still ping R9 IPv6 (routes reflected via RR)
6. On R3: `show bgp vpnv6 unicast all` — all VPNv6 routes present for reflection

### Task 11: 6PE via Route Reflectors

1. On R3 (RR): under `address-family ipv6 unicast`:
   - `neighbor <PEs> activate`
   - `neighbor <PEs> route-reflector-client`
   - `neighbor <PEs> send-label` (CRITICAL for 6PE via RR)
2. On PEs: remove direct ipv6 peering to other PEs. Keep only RR sessions.
3. Verify: 6PE routes (global table IPv6) reflected via RR with labels intact
4. Verify: R1 can ping R9 global IPv6 addresses via RR-reflected 6PE routes
5. **Key detail:** the `send-label` must be configured on the RR toward clients AND on clients toward RR for 6PE to work through reflection

---

## Section 5: IPv6 PE-CE Protocol Variations

### Task 12: OSPFv3 as PE-CE Protocol

1. On R8: configure OSPFv3 under VRF Customer_A:
   - `router ospfv3 2`
   - `address-family ipv6 unicast vrf Customer_A`
   - `redistribute bgp 64512`
2. On R8's VRF interface toward R9: `ospfv3 2 ipv6 area 0`
3. On R9: configure OSPFv3 to peer with R8:
   - `router ospfv3 1`
   - `address-family ipv6 unicast`
   - Interface: `ospfv3 1 ipv6 area 0`
4. On R8: redistribute OSPFv3 into BGP under `address-family ipv6 vrf Customer_A`
5. Verify: R9 learns R1's IPv6 prefixes via OSPFv3 (redistributed from BGP)
6. Verify: R1 (BGP PE-CE) can ping R9 (OSPFv3 PE-CE) — mixed protocols work for IPv6 too
7. Same concept as IPv4 mixed PE-CE (Lab 2 Task 5) — just with IPv6

### Task 13: Static IPv6 PE-CE

1. On R18 VRF Customer_E (or new IPv6 VRF): configure static IPv6 route:
   - `ipv6 route vrf Customer_E 2001:DB8:20::/48 <R20-link-local or global next-hop>`
2. Redistribute static into BGP under `address-family ipv6 vrf Customer_E`
3. On R20: configure static default route pointing to R18
4. Verify: R20 has IPv6 connectivity via static routes — simplest PE-CE for IPv6
5. **Same principle as IPv4 static PE-CE** — just with IPv6 addresses

---

## CCIE+ Challenges

### Challenge 1: 6PE + 6VPE Coexisting

1. On R2: run BOTH 6PE (global IPv6 via send-label) and 6VPE (IPv6 in VRF) simultaneously
2. 6PE handles internet IPv6 (global table)
3. 6VPE handles customer IPv6 VPN (per-VRF isolation)
4. Verify: global IPv6 routes have labels (6PE)
5. Verify: VRF IPv6 routes have VPN labels + RT (6VPE)
6. Verify: customer IPv6 VPN traffic is isolated from global IPv6 (different label stacks)
7. **SP model:** offer both IPv6 internet transit (6PE) and IPv6 VPN service (6VPE) from same PE

### Challenge 2: IPv6 Internet Access for VPN Customers

1. On R2: inject IPv6 default route into VRF Customer_A:
   - `ipv6 route vrf Customer_A ::/0 <global-table-next-hop>`
   - Redistribute into BGP under VRF
2. Verify: R1 receives IPv6 default route (::/0) via eBGP
3. Verify: R1 can reach "internet" IPv6 addresses (simulated via global table)
4. Verify: only Customer_A gets the IPv6 default — other VRFs don't
5. Same concept as IPv4 VRF internet access (Lab 2 Challenge 5) — IPv6 version

### Challenge 3: RT-Constraint for VPNv6

1. Enable RT-constraint (rtfilter) for vpnv6 on RRs:
   - Same concept as vpnv4 RT-constraint
2. Verify: PEs only receive vpnv6 routes for VRFs they have configured
3. R17 (Customer_D only): should NOT receive Customer_A vpnv6 routes
4. Add Customer_A IPv6 VRF to R17 — routes appear
5. Remove it — routes disappear
6. **Same principle as IPv4 RT-constraint** — just for the vpnv6 address-family

### Challenge 4: Dual-Stack CE with Single BGP Session (Multi-AFI)

1. On R1: configure a single BGP session to R2 that carries BOTH IPv4 and IPv6:
   - `neighbor 192.168.12.2 remote-as 64512`
   - `address-family ipv4`
   - `neighbor 192.168.12.2 activate`
   - `address-family ipv6`
   - `neighbor 192.168.12.2 activate`
2. One TCP session, two address families — no need for separate IPv6 peering
3. Verify: both IPv4 and IPv6 prefixes exchanged over the single session
4. On R2: `show ip bgp neighbors 192.168.12.1` — verify both AFI/SAFI negotiated
5. **Modern best practice:** single BGP session carries all address families (multi-AFI/SAFI)

---

## Final Validation

By the end of this lab, your network has:

- [ ] 6PE operational — IPv6 global routes with labels traversing IPv4 core
- [ ] P routers completely unaware of IPv6 (zero IPv6 config on core)
- [ ] CE-to-CE IPv6 ping working end-to-end via 6PE
- [ ] 6VPE operational — IPv6 inside VRFs with full customer isolation
- [ ] VPNv6 label stack understood (transport + VPN label, IPv6 payload)
- [ ] Dual-stack VRF providing both IPv4 and IPv6 in single customer VPN
- [ ] IPv6-only VRF proven (pure IPv6 customer over IPv4 core)
- [ ] VPNv6 reflected via Route Reflectors
- [ ] 6PE reflected via Route Reflectors with send-label
- [ ] Mixed PE-CE: eBGP + OSPFv3 + Static for IPv6
- [ ] (CCIE+) 6PE + 6VPE coexisting on same PE
- [ ] (CCIE+) IPv6 internet access for VPN customers
- [ ] (CCIE+) RT-constraint for vpnv6 reducing unnecessary distribution
- [ ] (CCIE+) Multi-AFI single BGP session carrying IPv4 + IPv6
