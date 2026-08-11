# MPLS SP Configuration Exam Practice Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — same physical topology as all labs
**Style:** INE CCIE-SP Lab Exam format
**Time Limit:** 8 hours (full workbook) or 2 hours per section
**Scoring:** 100 points total — Pass: 80/100

---

## Exam Rules

- You start with a **bare topology**: interfaces UP/UP with IP addresses assigned, hostnames set, telnet/console configured. NOTHING ELSE.
- You must configure everything from scratch based on requirements only
- No internet access, no notes (simulate exam conditions)
- Each task has a **verification command** — if it passes, you get the points
- Tasks are cumulative — later tasks depend on earlier ones being correct
- Partial credit: if the verification partially works, award half points
- **Do NOT copy/paste from your learning labs** — type from memory

---

## Starting State

All 20 routers have:
- Hostname configured (R1-R20)
- Interfaces UP with IP addresses per inventory (see topology diagram)
- Loopback0 with router-specific IP (X.X.X.X where X = router number)
- Console/VTY configured with password `cisco`
- No routing protocols, no MPLS, no BGP, no VRF, no QoS

**To reset to starting state:** Load the "Bare-IP" GNS3 snapshot

---

## Topology Diagram

```
        R1(CE)                                          R9(CE)
          |                                              |
       Fa0/0                                          Gi1/0
          |                                              |
        R2(PE)────Gi1/0────R3(P)────Fa0/0────R4(P)────Gi1/0────R5(P)────Gi2/0────R8(PE)
          |                  |                                    |                  |
       Gi2/0              Gi2/0                               Fa3/0              Fa0/0
          |                  |                                    |                  |
        R6(P)──────────────R7(P)                                R7(P)────────────R7(P)
          |                  |
       Fa4/0              Fa4/0
          |                  |
       R13(P)─────────────R14(P)
          |                  |
       Fa0/0              Fa0/0
          |                  |
       R17(PE)            R18(PE)
          |                  |
       Fa3/0              Gi2/0
          |                  |
       R19(CE)            R20(CE)

Additional links: R6↔R5, R13↔R15↔R16↔R14, R13↔R17, R15↔R17, R16↔R18
R12(CE)──Fa3/0──R2       R11(CE)──Fa4/0──R8
```

---

## Section 1: IGP & MPLS Foundation (20 points, ~45 min)

### Task 1.1 — OSPF Area 0 (4 points)

**Requirement:** Configure OSPF process 1 on all P and PE routers (R2-R8, R13-R18). All core-facing interfaces and loopbacks must be in Area 0. PE-CE interfaces must NOT be in OSPF. Use reference-bandwidth 10000.

**Verification:**
```
R2# show ip ospf neighbor | count FULL
```
Expected: All directly connected P/PE neighbors show FULL state.
```
R17# ping 8.8.8.8 source 17.17.17.17
```
Expected: 100% success.

---

### Task 1.2 — LDP & MPLS (4 points)

**Requirement:** Enable LDP on all core-facing interfaces. Configure per-router label ranges (R2=200-299, R3=300-399, R4=400-499, R5=500-599, R6=600-699, R7=700-799, R8=800-899, R13=1300-1399, R14=1400-1499, R15=1500-1599, R16=1600-1699, R17=1700-1799, R18=1800-1899). Do NOT enable MPLS on PE-CE interfaces.

**Verification:**
```
R2# show mpls ldp neighbor | count Oper
```
Expected: LDP sessions to all directly connected core neighbors.
```
R5# show mpls forwarding-table 8.8.8.8 32
```
Expected: Valid outgoing label and interface (not "No Label" or "Untagged").

---

### Task 1.3 — MPLS TE Foundation (4 points)

**Requirement:** Enable MPLS TE on all P/PE routers. Configure RSVP bandwidth 100000 on all core interfaces. Enable TE extensions under OSPF (router-id = Loopback0). Enable `mpls traffic-eng tunnels` on all core interfaces.

**Verification:**
```
R2# show mpls traffic-eng topology | count IGP Id
```
Expected: 13 routers visible in TE topology database (all P + PE).
```
R5# show ip rsvp interface | count [0-9]+K
```
Expected: All core interfaces show allocatable bandwidth.

---

### Task 1.4 — LDP Session Protection (4 points)

**Requirement:** Configure LDP session protection on all P and PE routers. Both sides of each adjacency must have protection configured. Targeted-hello accept must be enabled.

**Verification:**
```
R5# show mpls ldp discovery detail | include Targeted
```
Expected: Targeted hello entries for protected sessions.

Shut the link between R5 and R8:
```
R5# conf t → interface Gi2/0 → shutdown
```
Wait 5 seconds:
```
R5# show mpls ldp neighbor 8.8.8.8
```
Expected: LDP session to R8 still UP (via alternate path).

Bring interface back up.

---

### Task 1.5 — LDP-IGP Synchronization (4 points)

**Requirement:** Enable MPLS LDP IGP synchronization under OSPF process 1 on all P/PE routers. This prevents traffic from being sent to a link where the LDP session hasn't formed yet.

**Verification:**
```
R3# show mpls ldp igp sync
```
Expected: All interfaces show "Sync status: sync achieved" or "LDP configured".

---

## Section 2: L3VPN Service (25 points, ~60 min)

### Task 2.1 — Route Reflectors (5 points)

**Requirement:** Configure R3 and R7 as Route Reflectors for vpnv4 unicast. All PEs (R2, R8, R17, R18) are RR clients of BOTH R3 and R7. R3 and R7 peer with each other. All sessions use Loopback0 as update-source. Use ASN 64512. Send extended communities to all neighbors.

**Verification:**
```
R3# show ip bgp vpnv4 all summary
```
Expected: 5 peers (R2, R7, R8, R17, R18) all in Established state.
```
R7# show ip bgp vpnv4 all summary
```
Expected: 5 peers (R2, R3, R8, R17, R18) all in Established state.

---

### Task 2.2 — Customer_A VPN: Two-Site eBGP (5 points)

**Requirement:**
- VRF "Customer_A" on R2 and R8: RD 64512:100, RT import/export 64512:100
- R2 Fa0/0 in VRF Customer_A — eBGP with R1 (AS 65001)
- R8 Gi1/0 in VRF Customer_A — eBGP with R9 (AS 65001)
- R1 advertises 1.1.1.1/32; R9 advertises 9.9.9.9/32
- Both CEs are AS 65001 — handle the AS-path loop issue

**Verification:**
```
R1# ping 9.9.9.9
```
Expected: 100% success.
```
R9# ping 1.1.1.1
```
Expected: 100% success.
```
R2# show ip bgp vpnv4 vrf Customer_A | include 9.9.9.9
```
Expected: Route present with 2 labels.

---

### Task 2.3 — Customer_B VPN: Isolated Service (4 points)

**Requirement:**
- VRF "Customer_B" on R2 and R8: RD 64512:200, RT import/export 64512:200
- R2 Fa3/0 in VRF Customer_B — eBGP with R12 (AS 65012)
- R8 Fa4/0 in VRF Customer_B — eBGP with R11 (AS 65011)
- R12 advertises 12.12.12.12/32; R11 advertises 11.11.11.11/32
- Complete isolation from Customer_A

**Verification:**
```
R12# ping 11.11.11.11
```
Expected: 100% success.
```
R1# ping 12.12.12.12
```
Expected: 0% success (isolation — different VPN).

---

### Task 2.4 — Customer_D & E: South PEs (4 points)

**Requirement:**
- VRF "Customer_D" on R17: RD 64512:400, RT 64512:400. eBGP with R19 (AS 65019).
- VRF "Customer_E" on R18: RD 64512:500, RT 64512:500. eBGP with R20 (AS 65020).
- R19 advertises 19.19.19.19/32; R20 advertises 20.20.20.20/32.

**Verification:**
```
R17# show ip bgp vpnv4 vrf Customer_D
```
Expected: 19.19.19.19/32 locally originated, visible on RRs.
```
R18# show ip bgp vpnv4 vrf Customer_E
```
Expected: 20.20.20.20/32 locally originated.

---

### Task 2.5 — OSPF PE-CE for Customer_A Site 2 (4 points)

**Requirement:** Change the R8↔R9 PE-CE protocol from eBGP to OSPF:
- Remove eBGP between R8 and R9
- Configure OSPF process 2 on R8 under VRF Customer_A (area 0)
- Configure OSPF on R9 (area 0) to peer with R8
- Redistribute BGP into OSPF and OSPF into BGP on R8 (under VRF)
- R1 must still reach R9

**Verification:**
```
R1# ping 9.9.9.9
```
Expected: 100% success.
```
R9# show ip route 1.1.1.1
```
Expected: Shows as O E2 (OSPF external type 2 via redistribution).

---

### Task 2.6 — VPN Label Stack Verification (3 points)

**Requirement:** No configuration needed — demonstrate understanding by answering:
```
R2# show ip cef vrf Customer_A 9.9.9.9
```
Document: What two labels are pushed? Which is transport (top) and which is VPN (bottom)?
```
R7# show mpls forwarding-table
```
Document: Does R7 (P router) ever see or touch the VPN label?

**Verification:** Run the commands and confirm:
- Two labels imposed at R2 (ingress PE)
- P routers swap only the transport label
- PHP occurs one hop before R8
- R8 uses VPN label to identify the VRF

---

## Section 3: Traffic Engineering (20 points, ~45 min)

### Task 3.1 — Dynamic TE Tunnel R2→R8 (4 points)

**Requirement:** Create Tunnel0 on R2:
- Destination: 8.8.8.8
- Mode: mpls traffic-eng
- Path-option 1: dynamic
- Bandwidth: 50000
- Autoroute announce enabled
- IP unnumbered Loopback0

**Verification:**
```
R2# show mpls traffic-eng tunnels tunnel0 | include Admin|Oper|BW
```
Expected: Admin: up, Oper: up, Bandwidth: 50000.
```
R2# show ip route 8.8.8.8
```
Expected: Next-hop shows Tunnel0.

---

### Task 3.2 — Explicit Path Tunnel (4 points)

**Requirement:** Create Tunnel1 on R2:
- Destination: 8.8.8.8
- Explicit path: R3→R4→R5→R8 (use loopback IPs as next-addresses)
- Bandwidth: 80000
- Path-option 1: explicit name "VIA-NORTH"
- Path-option 2: dynamic (fallback)
- No autoroute (just verify it signals)

**Verification:**
```
R2# show mpls traffic-eng tunnels tunnel1 | include State|ERO
```
Expected: State UP with ERO showing R3, R4, R5, R8.

---

### Task 3.3 — TE Tunnel Carries VPN Traffic (4 points)

**Requirement:** Ensure Customer_A VPN traffic from R2 to R8 uses Tunnel0 (not the LDP path). Autoroute should handle this if configured correctly in Task 3.1.

**Verification:**
```
R2# show ip cef vrf Customer_A 9.9.9.9 | include Tunnel
```
Expected: Output shows Tunnel0 as the outgoing interface.
```
R1# traceroute 9.9.9.9
```
Expected: Path matches Tunnel0's computed route.

---

### Task 3.4 — Link Coloring / Affinity (4 points)

**Requirement:**
- Mark the R6↔R13 link with attribute-flag 0x1 (color "gold") on both sides
- Create Tunnel2 on R2 with destination 17.17.17.17, bandwidth 30000
- Tunnel2 must ONLY use links with attribute 0x1 (affinity 0x1 mask 0x1)
- Since only R6↔R13 has 0x1, the tunnel must traverse that specific link

**Verification:**
```
R2# show mpls traffic-eng tunnels tunnel2 | include ERO
```
Expected: ERO includes the R6↔R13 hop.
```
R6# show mpls traffic-eng link-management bandwidth-allocation interface Fa4/0
```
Expected: Shows 30000 reserved.

---

### Task 3.5 — Fast Reroute (Link Protection) (4 points)

**Requirement:**
- Enable FRR on Tunnel0 (R2→R8): `tunnel mpls traffic-eng fast-reroute`
- Create a backup tunnel on R2 that protects the first link of Tunnel0's path
- The backup tunnel should bypass the protected link and merge back to the primary path

**Verification:**
```
R2# show mpls traffic-eng tunnels tunnel0 | include FRR
```
Expected: "Fast Reroute Protection: Enabled, Protection: Ready"
```
R2# show mpls traffic-eng fast-reroute database
```
Expected: Shows a backup entry protecting Tunnel0's primary path.

---

## Section 4: Advanced VPN Design (20 points, ~45 min)

### Task 4.1 — Hub-Spoke VPN (5 points)

**Requirement:** Redesign Customer_B as hub-spoke:
- R2 is the hub PE (R12 = hub CE)
- R8 is the spoke PE (R11 = spoke CE)
- Spoke routes must transit through the hub (R12) before reaching other spokes
- Hub RT design: Hub exports RT 64512:201, imports RT 64512:202. Spoke exports RT 64512:202, imports RT 64512:201.
- Hub CE (R12) must have routes from all spoke CEs

**Verification:**
```
R12# show ip route 11.11.11.11
```
Expected: Route present (hub CE sees spoke routes).
```
R11# show ip route 12.12.12.12
```
Expected: Route present with next-hop via R8 (spoke CE reaches hub).
```
R2# show ip route vrf Customer_B 11.11.11.11
```
Expected: Route has RT 64512:202 (came from spoke, imported by hub).

---

### Task 4.2 — Shared Services VRF (4 points)

**Requirement:**
- Create VRF "Shared_Services" on R2: RD 64512:900
- RT export: 64512:900
- RT import: 64512:100, 64512:200, 64512:900 (imports from Customer_A and Customer_B)
- On Customer_A VRF: add RT import 64512:900 (can reach shared services)
- Place a Loopback10 (10.99.99.1/32) on R2 in the Shared_Services VRF
- Customer_A CEs must reach 10.99.99.1; Customer_B CEs must reach 10.99.99.1
- Customer_A and Customer_B must NOT reach each other

**Verification:**
```
R1# ping 10.99.99.1
```
Expected: 100% success (Customer_A reaches shared services).
```
R12# ping 10.99.99.1
```
Expected: 100% success (Customer_B reaches shared services).
```
R1# ping 12.12.12.12
```
Expected: 0% success (Customer_A cannot reach Customer_B directly).

---

### Task 4.3 — Selective Route Leaking with Export-Map (4 points)

**Requirement:**
- Customer_A should share ONLY its loopback routes (1.1.1.1/32, 9.9.9.9/32) with Customer_B
- Customer_A transit links (192.168.x.x) must NOT leak
- Use an export-map on R2 that adds an extra RT (64512:150) only to loopback routes
- On Customer_B VRF: import RT 64512:150 in addition to 64512:200
- Result: Customer_B CEs can reach R1 and R9 loopbacks but not their transit links

**Verification:**
```
R12# ping 1.1.1.1
```
Expected: 100% success (loopback leaked).
```
R12# ping 192.168.12.1
```
Expected: 0% success (transit link NOT leaked).

---

### Task 4.4 — RT-Constrained Route Distribution (4 points)

**Requirement:**
- Enable address-family rtfilter unicast on both RRs (R3, R7) and all PEs
- After enabling, verify that PEs only receive vpnv4 routes matching their locally configured VRF RTs
- R17 (only has Customer_D) should NOT receive Customer_A/B/E routes
- R18 (only has Customer_E) should NOT receive Customer_A/B/D routes

**Verification:**
```
R17# show ip bgp vpnv4 all | count 64512:
```
Expected: Only shows prefixes with RD 64512:400 (Customer_D). No 64512:100/200/500.
```
R18# show ip bgp vpnv4 all | count 64512:
```
Expected: Only shows prefixes with RD 64512:500 (Customer_E).

---

### Task 4.5 — Inter-AS Option A (3 points)

**Requirement:**
- Treat R6 as an ASBR between "north" and "south" domains
- Create VRF "Customer_A_InterAS" on R6, assign the interface toward R13
- Create VRF "Customer_A_InterAS" on R13, assign the interface toward R6
- Configure eBGP between R6 and R13 under the VRF (use AS 64512 on R6, AS 64513 on R13 for the exercise)
- R6 must import Customer_A routes from its vpnv4 table into the inter-AS VRF
- R13 must pass them to R17, which also has Customer_A VRF
- Result: R19 (south) can reach R1 (north) via the inter-AS link

**Verification:**
```
R19# ping 1.1.1.1 source 19.19.19.19
```
Expected: 100% success (traffic traverses inter-AS boundary).

---

## Section 5: Protection, OAM & Convergence (15 points, ~30 min)

### Task 5.1 — MPLS OAM: LSP Ping & Traceroute (3 points)

**Requirement:** Verify MPLS data plane for all PE-to-PE LSPs using LSP ping and MPLS traceroute.

**Verification:**
```
R2# ping mpls ipv4 8.8.8.8/32
```
Expected: 5/5 success.
```
R2# traceroute mpls ipv4 17.17.17.17/32
```
Expected: Full path with labels shown at each hop.

---

### Task 5.2 — TTL Propagation Security (3 points)

**Requirement:** Disable TTL propagation for forwarded packets on all PE routers. Core P routers should be invisible to CE traceroutes.

**Verification:**
```
R1# traceroute 9.9.9.9
```
Expected: Only R2 and R8 visible as hops (P routers hidden — 3 hops total: R2, R8, R9).

---

### Task 5.3 — BFD for OSPF (3 points)

**Requirement:** Enable BFD on all OSPF adjacencies between P routers (core links only). Use interval 100ms, minimum-rx 100ms, multiplier 3. This gives 300ms failure detection.

**Verification:**
```
R5# show bfd neighbors | count UP
```
Expected: BFD sessions matching OSPF neighbor count.
```
R5# show bfd neighbors detail | include Interval
```
Expected: Shows 100ms intervals.

---

### Task 5.4 — OSPF Fast Convergence (3 points)

**Requirement:** Tune OSPF for sub-second convergence:
- SPF throttle: initial 50ms, second 200ms, max 5000ms
- LSA throttle: initial 50ms, second 200ms, max 5000ms
- Interface dead-interval minimal hello-multiplier 4 (250ms dead) on all core links

**Verification:**
```
R3# show ip ospf | include SPF schedule
```
Expected: Shows throttle timers matching configured values.

---

### Task 5.5 — Prefix Suppression (3 points)

**Requirement:** Enable OSPF prefix suppression on all transit links (P-to-P and PE-to-P). Loopbacks must NOT be suppressed. Only transit /30 prefixes should be hidden from the routing table (reducing RIB/FIB size).

**Verification:**
```
R2# show ip route ospf | count /30
```
Expected: Zero or near-zero /30 transit routes (all suppressed).
```
R2# show ip route ospf | count /32
```
Expected: All PE and P loopbacks still present.

---

## Scoring Summary

| Section | Topics | Points | Time |
|---|---|---|---|
| 1 | IGP, MPLS, LDP, TE Foundation | 20 | 45 min |
| 2 | L3VPN (VRFs, PE-CE, RRs, label stack) | 25 | 60 min |
| 3 | Traffic Engineering (tunnels, paths, FRR) | 20 | 45 min |
| 4 | Advanced VPN (hub-spoke, shared, extranet, inter-AS) | 20 | 45 min |
| 5 | OAM, Protection, Convergence | 15 | 30 min |
| **Total** | | **100** | **~4 hours** |

---

## Grading

| Score | Level | Meaning |
|---|---|---|
| 90-100 | CCIE-SP Ready | You can configure any SP network from requirements |
| 80-89 | CCNP-SP Pass + | Solid exam performance, minor gaps |
| 65-79 | CCNP-SP Level | Good foundation, need more practice on advanced topics |
| 50-64 | Developing | Review learning labs for weak areas |
| <50 | Restart | Go back to learning labs and rebuild fundamentals |

---

## After Completion

Once you score 90+, you're ready for:
1. **Timed run:** Do the entire workbook in 4 hours (no breaks)
2. **Blind run:** Have the AI reset your topology and give you ONLY the requirements (no verification hints)
3. **Combined:** Configure + immediately troubleshoot (AI breaks something after you finish each section)

---

## How to Use with the AI

```
You: "Reset my topology to bare-IP and start the config exam"
AI:  Connects to all routers → removes all config except interfaces/IPs → "Ready. Timer starts."
You: Configure each section
You: "Verify section 1"
AI:  Runs verification commands → scores you → "Section 1: 16/20. Task 1.4 failed — LDP session didn't survive shutdown."
```
