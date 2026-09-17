# E01: IS-IS + Transport Foundation

**Platform:** IOS-XRv 9000 on GNS3/EC2
**Topology:** `00_topology_reference.md` — Emerald AS 65100 + Gold AS 65300 + Garnet AS 65200
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3

**End Goal:** IS-IS L2 on all 3 SPs. LDP on Emerald. SR-MPLS on Garnet. Full PE-PE LSP in each AS.

---

## Section 1: Emerald AS 65100 (IS-IS + LDP) - DONE

### Task 1: IP Addressing
1. Configure loopbacks and core link IPs on PE1, PE2, P1, P2, ASBR1, PCE1 per the topology reference.
2. Verify: every directly connected link can ping its neighbor.

### Task 2: IS-IS on Emerald core
1. On each Emerald router: `router isis CORE / is-type level-2-only / net 49.0001.0000.0000.000X.00 / address-family ipv4 unicast / metric-style wide`.
2. Enable IS-IS on Loopback0 (passive) + all **core** interfaces (point-to-point). NOT on PE-CE interfaces.
   - PE1: Gi0/0/0/2, Gi0/0/0/3 (core). NOT Gi0/0/0/0, Gi0/0/0/1 (PE-CE).
   - PE2: Gi0/0/0/0, Gi0/0/0/3 (core). NOT Gi0/0/0/1, Gi0/0/0/2 (PE-CE).
   - P1: Gi0/0/0/0, Gi0/0/0/1, Gi0/0/0/2 (all core).
   - P2: Gi0/0/0/1, Gi0/0/0/2, Gi0/0/0/3 (all core).
   - ASBR1: Gi0/0/0/2 (core). NOT Gi0/0/0/0 (inter-AS).
   - PCE1: Gi0/0/0/3 (core).
3. Verify: `show isis neighbors` — all adjacencies L2/UP.
4. Verify: `show route ipv4` — all 6 Emerald loopbacks (1.1.1.1–6.6.6.6) reachable.

### Task 3: LDP on Emerald core
1. `mpls ldp / router-id <loopback> / address-family ipv4` + enable on ALL core interfaces.
2. Verify: `show mpls ldp neighbor` — sessions match IS-IS neighbors.
3. Verify: `show mpls forwarding` — labels for all loopbacks.
4. `traceroute mpls ipv4 2.2.2.2/32` from PE1 — PUSH/SWAP/POP verified.

---

## Section 2: Garnet AS 65200 (IS-IS + SR-MPLS) - DONE

### Task 4: IP Addressing
1. Configure loopbacks and core link IPs on PE3, PE4, P3, P4, P5, ASBR2, PCE per the topology reference.

### Task 5: IS-IS + SR on Garnet core
1. Same IS-IS config as Emerald + add `segment-routing mpls` under address-family.
2. Prefix-SID on each Loopback0:
   - PE3=index 11 (16011), PE4=12, P3=13, P4=14, P5=15, ASBR2=16, PCE=17
3. Enable IS-IS on core interfaces only:
   - PE3: Gi0/0/0/1, Gi0/0/0/3 (core). NOT Gi0/0/0/0, Gi0/0/0/2 (PE-CE).
   - PE4: Gi0/0/0/2, Gi0/0/0/3 (core). NOT Gi0/0/0/0, Gi0/0/0/1 (PE-CE).
   - P3: Gi0/0/0/0, Gi0/0/0/1, Gi0/0/0/2, Gi0/0/0/3 (all core).
   - P4: Gi0/0/0/0, Gi0/0/0/1, Gi0/0/0/3 (all core).
   - P5: Gi0/0/0/1, Gi0/0/0/2, Gi0/0/0/3 (all core).
   - ASBR2: Gi0/0/0/2 (core). NOT Gi0/0/0/1 (inter-AS).
   - PCE: Gi0/0/0/3 (core).
4. **No LDP on Garnet** — SR replaces it.
5. Verify: `show isis segment-routing label table` — SIDs 16011–16017.
6. Verify: `show mpls forwarding` — SR labels in LFIB.
7. `ping 12.12.12.12 source 11.11.11.11` from PE3 — works via SR.

### Task 6: Verify no cross-AS connectivity yet
1. PE1 cannot reach PE3: `ping 11.11.11.11` from PE1 → fails. Expected. Inter-AS = Lab E06.

---

## Section 3: Snapshot
1. Take GNS3 snapshot: **"E01-isis-ldp-sr-foundation"**

---

## Verification Checklist
```
[ ] Emerald: IS-IS L2 adjacencies on all core links
[ ] Emerald: all 6 loopbacks reachable via IS-IS
[ ] Emerald: LDP sessions match IS-IS neighbors; LFIB populated
[ ] Emerald: traceroute mpls shows PUSH/SWAP/POP
[ ] Garnet: IS-IS L2 + SR on all core links
[ ] Garnet: prefix-SIDs 16011-16017 in label table
[ ] Garnet: SR labels in LFIB (no LDP)
[ ] Garnet: PE3↔PE4 ping works via SR
[ ] No cross-AS connectivity (expected)
```

---

## Section 3: Gold AS 65300 (IS-IS + SRv6)

### Task 7: IP Addressing on Gold
1. Configure loopbacks and core link IPs on ASBR3(21.21.21.21), ASBR4(22.22.22.22), P6(23.23.23.23), PE5(24.24.24.24), PE6(25.25.25.25).

### Task 8: IS-IS + SRv6 on Gold core
1. IS-IS L2 on all Gold routers (net 49.0003...). `metric-style wide`.
2. IPv6 on all Gold core interfaces (for SRv6 data plane).
3. `segment-routing srv6` with locator per router (e.g., PE5 = fc00:0:24::/48).
4. Enable IS-IS on core interfaces:
   - ASBR3: Gi0/0/0/1 (P6), Gi0/0/0/2 (ASBR4). NOT Gi0/0/0/3 (inter-AS to Emerald).
   - ASBR4: Gi0/0/0/0 (P6), Gi0/0/0/2 (ASBR3). NOT Gi0/0/0/3 (inter-AS to Garnet).
   - P6: Gi0/0/0/0 (ASBR4), Gi0/0/0/1 (ASBR3), Gi0/0/0/2 (PE5), Gi0/0/0/3 (PE6).
   - PE5: Gi0/0/0/2 (P6). NOT Gi0/0/0/0 (CE9), Gi0/0/0/1 (CE8).
   - PE6: Gi0/0/0/3 (P6). NOT Gi0/0/0/0 (CE7), Gi0/0/0/1 (CE8).
5. ASBR3 = RR + PCE for Gold.
6. **No LDP on Gold** — SRv6 provides transport.
7. Verify: `show segment-routing srv6 sid` on each Gold router — SIDs allocated.
8. PE5 ↔ PE6 ping works via SRv6.

### Task 9: Verify inter-AS links (no IGP/LDP across them)
1. ASBR1(Gi3) ↔ ASBR3(Gi3) — link UP, no IS-IS. eBGP later (E06).
2. ASBR4(Gi3) ↔ ASBR2(Gi3) — link UP, no IS-IS. eBGP later (E06).
3. ASBR1(Gi1) ↔ ASBR2(Gi1) — link UP, no IS-IS. eBGP later (E06). Direct Emerald↔Garnet path.

### Updated Checklist
```
[ ] Emerald: IS-IS + LDP (6 routers, all loopbacks reachable)
[ ] Gold: IS-IS + SRv6 (5 routers, SRv6 SIDs allocated, PE5↔PE6 works)
[ ] Garnet: IS-IS + SR-MPLS (7 routers, prefix-SIDs, PE3↔PE4 works)
[ ] 3 inter-AS links UP but no IGP across them
[ ] 3 different transport technologies operational (LDP / SRv6 / SR-MPLS)
```
