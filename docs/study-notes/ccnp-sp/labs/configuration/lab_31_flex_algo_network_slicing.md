# Lab 31: Flex-Algo & Network Slicing — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 2 RRs, 6 CEs. Full MPLS core with SR-MPLS.
**Prerequisite:** Lab 16 complete (Segment Routing with prefix-SIDs, IS-IS/OSPF with SR extensions operational)

**End Goal:** Define multiple Flexible Algorithms (Flex-Algo) to create logical network slices over a shared physical infrastructure. Each algorithm computes independent shortest paths using different metrics (IGP, TE, delay) and constraints (affinities). Traffic is steered into the appropriate slice via per-algorithm prefix-SIDs. By the end, you understand how Flex-Algo enables intent-based networking for 5G slicing, low-latency applications, and differentiated services without explicit per-tunnel configuration.

**⚠️ Platform Note:** Flex-Algo requires IOS-XR 7.0+ or IOS-XE 17.x+. Cisco 7200/IOS 15.2 does NOT support Flex-Algo. This lab provides full configuration syntax for IOS-XR reference and documents the concepts thoroughly. Use EVE-NG with IOS-XRv 9000 or CSR1000v for hands-on validation.

---

## Section 1: Flex-Algo Fundamentals

### Task 1: Understand Flex-Algo Concepts

1. **Default Algorithm (Algo 0):** standard SPF using IGP metric — what every router runs today
2. **Flex-Algo (Algo 128-255):** custom algorithms defined by operator, advertised via IGP
3. **Key properties per Flex-Algo:**
   - Metric type: IGP metric, TE metric, or link delay
   - Affinity constraints: include-any, include-all, exclude-any
   - Calculation type: SPF (shortest path first)
4. **Prefix-SID per algorithm:** each router advertises a DIFFERENT prefix-SID per algorithm
   - Algo 0: prefix-SID index 1 (R2 = label 16001)
   - Algo 128: prefix-SID index 101 (R2 = label 16101)
   - Algo 129: prefix-SID index 201 (R2 = label 16201)
5. **Result:** steering traffic via label 16101 forces it through Algo 128's topology (e.g., low-delay path)
6. Document: why Flex-Algo replaces SR-TE explicit policies for common traffic steering cases

### Task 2: Define Flex-Algo 128 (Low Latency)

1. On R3 (Flex-Algo definition advertisement source):
   ```
   ! IOS-XR:
   router isis CORE
    flex-algo 128
     metric-type delay
     advertise-definition
   ```
2. **metric-type delay:** Algo 128 computes SPF using link delay (not IGP cost)
3. All routers participating in Algo 128 will compute independent SPF using delay as metric
4. Verify: `show isis flex-algo 128` — definition advertised, metric type = delay
5. **Who advertises the definition?** Any router can, but typically a designated router (like RR or P router)
6. If multiple routers advertise conflicting definitions: highest router-ID wins
7. **Best practice:** advertise definition from 2+ routers for redundancy (same definition)

### Task 3: Define Flex-Algo 129 (High Bandwidth — TE Metric)

1. On R3:
   ```
   router isis CORE
    flex-algo 129
     metric-type te
     advertise-definition
   ```
2. **metric-type te:** Algo 129 uses TE metric for path computation
3. TE metric can be set independently of IGP metric — allows different path selection
4. Verify: `show isis flex-algo 129` — definition advertised
5. Document: how operators set TE metric vs IGP metric:
   - IGP metric: typically based on bandwidth (higher bandwidth = lower cost)
   - TE metric: can be tuned for traffic engineering (independent of bandwidth)
   - Delay metric: measured/configured latency per link

### Task 4: Define Flex-Algo 130 (Constrained Topology — Affinity)

1. On R3:
   ```
   router isis CORE
    flex-algo 130
     affinity exclude-any GREEN
     metric-type igp
     advertise-definition
   ```
2. **Affinity constraint:** Algo 130 excludes all links colored GREEN
3. Result: a sub-topology that avoids specific links (e.g., submarine cables, international links)
4. Define affinity: on each interface:
   ```
   router isis CORE
    interface GigabitEthernet0/0/0/0
     affinity flex-algo
      color GREEN
   ```
5. Verify: `show isis flex-algo 130` — exclude-any GREEN constraint visible
6. **Use case:** "disjoint plane" — Algo 130 avoids submarine links (data sovereignty)

---

## Section 2: Per-Algorithm Prefix-SIDs

### Task 5: Configure Prefix-SIDs for Each Algorithm

1. On R2 (PE): allocate prefix-SIDs per algorithm:
   ```
   router isis CORE
    interface Loopback0
     address-family ipv4 unicast
      prefix-sid index 1                ! Algo 0 (default)
      prefix-sid algorithm 128 index 101  ! Algo 128 (low-latency)
      prefix-sid algorithm 129 index 201  ! Algo 129 (TE metric)
      prefix-sid algorithm 130 index 301  ! Algo 130 (constrained)
   ```
2. Repeat on ALL participating routers with unique indices:

| Router | Algo 0 SID | Algo 128 SID | Algo 129 SID | Algo 130 SID |
|--------|-----------|-------------|-------------|-------------|
| R2 | 16001 | 16101 | 16201 | 16301 |
| R3 | 16002 | 16102 | 16202 | 16302 |
| R4 | 16003 | 16103 | 16203 | 16303 |
| R5 | 16004 | 16104 | 16204 | 16304 |
| R6 | 16005 | 16105 | 16205 | 16305 |
| R7 | 16006 | 16106 | 16206 | 16306 |
| R8 | 16007 | 16107 | 16207 | 16307 |
| R13 | 16008 | 16108 | 16208 | 16308 |
| R14 | 16009 | 16109 | 16209 | 16309 |
| R15 | 16010 | 16110 | 16210 | 16310 |
| R16 | 16011 | 16111 | 16211 | 16311 |
| R17 | 16012 | 16112 | 16212 | 16312 |
| R18 | 16013 | 16113 | 16213 | 16313 |

3. Verify: `show isis segment-routing label table` — labels for all algorithms visible
4. Verify: `show mpls forwarding` — separate label entries per algorithm per destination
5. **Key insight:** label 16107 (Algo 128 to R8) may follow DIFFERENT path than 16007 (Algo 0 to R8)

### Task 6: Verify Independent Path Computation

1. Configure link delays on core interfaces (IOS-XR):
   ```
   performance-measurement
    interface GigabitEthernet0/0/0/0
     delay-measurement
      advertise-delay 10000   ! 10ms
   ```
   Set different delays per link:
   - R2→R3: 5ms, R3→R5: 2ms, R5→R7: 3ms (total via north: 10ms)
   - R2→R4: 2ms, R4→R6: 2ms, R6→R7: 2ms, R7→R8: 1ms (total via south: 7ms)
2. **Algo 0 (IGP metric):** path R2→R3→R5→R7→R8 (if IGP cost is lower this way)
3. **Algo 128 (delay metric):** path R2→R4→R6→R7→R8 (lower total delay: 7ms vs 10ms)
4. On R2: `show cef 8.8.8.8/32` — Algo 0 path
5. On R2: `show cef 8.8.8.8/32 algorithm 128` — Algo 128 path (DIFFERENT!)
6. Verify: `traceroute mpls segment-routing 16007` — follows Algo 0 path
7. Verify: `traceroute mpls segment-routing 16107` — follows Algo 128 path
8. **Proof:** same destination, different algorithms → different physical paths

### Task 7: Flex-Algo Topology Pruning (Affinity)

1. Color specific links GREEN:
   ```
   router isis CORE
    interface GigabitEthernet0/0/0/1
     affinity flex-algo
      color GREEN
   ```
   (Apply GREEN to links R3↔R5 and R5↔R7)
2. **Algo 130 excludes GREEN:** these links are pruned from Algo 130's topology
3. Verify: `show isis flex-algo 130 topology` — links marked GREEN are absent
4. On R2: `show cef 8.8.8.8/32 algorithm 130` — path avoids R3-R5-R7 corridor
5. Compare: `show cef 8.8.8.8/32 algorithm 0` — may use R3-R5-R7 (IGP shortest)
6. **Result:** Algo 130 traffic is physically isolated from GREEN links — network slicing
7. Verify: if removing GREEN links makes R8 unreachable via Algo 130 → label not installed (correct — no path exists in that slice)

---

## Section 3: Steering Traffic into Flex-Algo Paths

### Task 8: SR-TE Policy with Flex-Algo Segment

1. On R2: create SR-TE policy using Algo 128 prefix-SID:
   ```
   segment-routing
    traffic-eng
     policy LOW-LATENCY-TO-R8
      color 128 end-point ipv4 8.8.8.8
      candidate-paths
       preference 100
        explicit segment-list ALGO128-PATH
    segment-lists
     segment-list ALGO128-PATH
      index 10 mpls label 16107   ! Algo 128 SID for R8
   ```
2. Verify: `show segment-routing traffic-eng policy` — policy UP
3. Traffic steered via color 128 → uses Algo 128 path (low-latency)
4. **Simplicity vs explicit SR-TE:** single label steers traffic through entire Algo 128 topology
5. No need to specify intermediate hops — Algo 128's SPF handles optimal path selection
6. Verify: `traceroute` from R2 via this policy — follows delay-optimized path

### Task 9: BGP Color Community Steering into Flex-Algo

1. On R2: steer VPN traffic using BGP color to select Flex-Algo:
   ```
   route-policy COLOR-128
    set extcommunity color 128
   end-policy
   !
   router bgp 64512
    vrf CUSTOMER_PREMIUM
     neighbor 192.168.12.1
      address-family ipv4 unicast
       route-policy COLOR-128 out
   ```
2. BGP next-hop for Customer_PREMIUM → color 128 → maps to Algo 128 SR-TE policy
3. Verify: `show cef vrf CUSTOMER_PREMIUM <prefix>` — uses Algo 128 label
4. Configure Customer_STANDARD with color 0 → uses default Algo 0 path
5. **Service differentiation:**
   - Premium customers → color 128 → Algo 128 (low-latency path)
   - Standard customers → color 0 → Algo 0 (IGP shortest path)
6. Both share the same physical infrastructure — Flex-Algo provides logical separation
7. Verify: traceroute from Premium customer vs Standard customer → different paths

### Task 10: ODN (On-Demand Next-Hop) with Flex-Algo

1. Configure ODN to auto-create SR-TE policies based on color:
   ```
   segment-routing
    traffic-eng
     on-demand color 128
      dynamic
       metric type latency
       sid-algorithm 128
     on-demand color 129
      dynamic
       metric type te
       sid-algorithm 129
   ```
2. When BGP route with color 128 arrives → SR-TE policy auto-created using Algo 128
3. Verify: add VPN route with color 128 → policy appears in `show segment-routing traffic-eng policy`
4. Remove route → policy auto-deleted
5. **Scalability:** no pre-provisioned policies per destination — ODN + Flex-Algo = fully dynamic
6. Verify: multiple destinations with color 128 all use Algo 128 paths (different per-destination)
7. **5G analogy:** URLLC slice = color 128 (low-latency), eMBB slice = color 129 (high-bandwidth)

---

## Section 4: Network Slicing Use Cases

### Task 11: 5G Network Slicing (Conceptual Design)

1. **Design three slices for 5G transport:**
   - **Slice A — URLLC (Ultra-Reliable Low-Latency):** Algo 128, delay metric, includes only low-latency links
   - **Slice B — eMBB (Enhanced Mobile Broadband):** Algo 129, TE metric, all high-capacity links
   - **Slice C — mMTC (Massive Machine-Type Communications):** Algo 0, default IGP metric (best effort)
2. Map each slice to a color community:
   - URLLC → color 128
   - eMBB → color 129
   - mMTC → no color (default)
3. Configure VRFs per slice type:
   - VRF URLLC_TRANSPORT: all routes get color 128
   - VRF EMBB_TRANSPORT: all routes get color 129
   - VRF MMTC: default routing (no color)
4. Verify: traffic from each VRF follows its designated Flex-Algo path
5. Document: how the SP achieves SLA isolation without physical separation

### Task 12: Low-Latency Financial Services Slice

1. **Use case:** financial trading firm requires <10ms latency between Site A and Site B
2. Configure Algo 128 with delay metric:
   - Only links with measured delay <5ms participate
   - Higher-delay links (satellite, submarine) excluded via affinity
3. Configure affinity HIGH-DELAY on slow links:
   ```
   router isis CORE
    flex-algo 128
     affinity exclude-any HIGH-DELAY
     metric-type delay
   ```
4. Verify: path from R2 to R8 via Algo 128 uses only low-delay links
5. Measure end-to-end delay: `show performance-measurement delay summary`
6. **SLA verification:** if measured delay exceeds 10ms → alarm (Algo 128 path may be suboptimal)
7. Compare: Algo 0 path may traverse high-delay links — unacceptable for trading traffic

### Task 13: Disjoint Redundancy Planes

1. **Use case:** two completely disjoint forwarding planes for resilience
2. Define two Flex-Algos with complementary constraints:
   ```
   ! Plane A — uses BLUE links only
   flex-algo 131
    affinity include-all BLUE
    metric-type igp
   
   ! Plane B — uses RED links only
   flex-algo 132
    affinity include-all RED
    metric-type igp
   ```
3. Color links: assign BLUE or RED to each link (ensure both planes have full connectivity)
4. Verify: Algo 131 and Algo 132 compute COMPLETELY DIFFERENT paths
5. **Application:** primary traffic on Plane A, backup on Plane B — zero shared failure domain
6. Verify: shut ALL blue links → Plane A fails, Plane B unaffected
7. **Dual-homing:** steer primary traffic via Algo 131 label, backup via Algo 132 label

---

## Section 5: Flex-Algo Operations and Troubleshooting

### Task 14: Flex-Algo Participation and Non-Participation

1. **Not all routers must participate in every algorithm**
2. On R14: do NOT configure Algo 128 prefix-SID → R14 does not participate
3. Verify: Algo 128's topology computes paths AROUND R14 (it's not in the slice)
4. **Benefit:** restrict a slice to specific hardware (e.g., only routers with hardware timestamping participate in low-latency slice)
5. On R2: `show isis flex-algo 128 topology` — R14 absent from topology
6. Add Algo 128 prefix-SID to R14 → R14 joins the slice, topology recomputes
7. Verify: `show isis flex-algo 128 topology` — R14 now included
8. **Operational model:** add routers to slices by simply configuring the prefix-SID

### Task 15: Flex-Algo Monitoring and Verification

1. Verify algorithm definitions are consistent across the network:
   ```
   show isis flex-algo 128 detail
   show isis flex-algo 129 detail
   show isis flex-algo 130 detail
   ```
2. Check for definition conflicts: `show isis flex-algo conflicts`
3. Verify label installation per algorithm:
   ```
   show isis segment-routing label table algorithm 128
   show mpls forwarding labels 16101 16107 16112 16113
   ```
4. Verify forwarding path per algorithm:
   ```
   show cef <destination>/32 algorithm 128
   show cef <destination>/32 algorithm 129
   ```
5. **Troubleshooting:** if Algo 128 label not installed for a destination:
   - Check: does destination participate in Algo 128? (has prefix-SID for algo 128?)
   - Check: is there a valid path in Algo 128's pruned topology?
   - Check: is the flex-algo definition received from IGP?
6. `show isis database detail` — verify TLVs carry flex-algo definition
7. Document: common failure modes (no path in pruned topology, missing participation, definition conflict)

### Task 16: Flex-Algo with TI-LFA Protection

1. **TI-LFA works per-algorithm:** backup path computed within the algorithm's topology
2. Verify: `show isis fast-reroute algorithm 128 <prefix> detail` — backup path within Algo 128
3. Simulate link failure on Algo 128's path → verify TI-LFA switches within Algo 128 topology
4. **Constraint:** backup path must ALSO satisfy Algo 128's constraints (delay metric, affinities)
5. If no backup path exists within the algorithm → no protection (traffic drops until reconvergence)
6. Verify: `show isis fast-reroute summary algorithm 128` — protection coverage percentage
7. **Design consideration:** ensure algorithm topology has sufficient redundancy for TI-LFA

---

## CCIE+ Challenges

### Challenge 1: Flex-Algo with Measurement-Based Delay

1. Configure real-time delay measurement (TWAMP/PM):
   ```
   performance-measurement
    interface GigabitEthernet0/0/0/0
     delay-measurement
   ```
2. Let measured delay advertise into IS-IS (replaces static delay values)
3. Verify: `show performance-measurement interfaces` — measured delay per link
4. Verify: Algo 128 path CHANGES as measured delay fluctuates
5. **Dynamic slicing:** network automatically adapts to real-time conditions
6. Simulate: add 20ms delay on a link → Algo 128 reroutes around it automatically
7. **Challenge:** prevent route flapping — configure dampening for delay changes

### Challenge 2: Flex-Algo Definition Priority and Conflict Resolution

1. Configure DIFFERENT Algo 128 definitions on R3 and R7:
   - R3: Algo 128 = metric-type delay
   - R7: Algo 128 = metric-type te
2. Observe: which definition wins? (Higher router-ID or specific priority rules)
3. Verify: `show isis flex-algo 128 | include winner`
4. **Danger:** conflicting definitions cause unpredictable behavior — always use consistent definitions
5. Fix: remove conflicting definition from R7
6. Configure priority on definition advertisement:
   ```
   flex-algo 128
    priority 200
   ```
7. Higher priority wins regardless of router-ID

### Challenge 3: Flex-Algo with Inter-Area/Inter-Level

1. **Question:** does Flex-Algo work across IS-IS levels or OSPF areas?
2. Configure two IS-IS levels: Level-1 (access) and Level-2 (core)
3. Advertise Flex-Algo definition in Level-2
4. Verify: Level-1 routers receive the definition and participate
5. Test: prefix-SID for Algo 128 reachable across level boundaries
6. **Caveat:** both levels must support the same Flex-Algo definition
7. Document: Flex-Algo behavior at ABR/L1L2 boundary routers

### Challenge 4: Maximum Flex-Algo Scale Test

1. Define 8 Flex-Algorithms (128-135) with different constraints:
   - 128: delay metric
   - 129: TE metric
   - 130: exclude GREEN
   - 131: include-all BLUE
   - 132: include-all RED
   - 133: delay + exclude HIGH-DELAY
   - 134: IGP + include-all FIBER
   - 135: TE + exclude WIRELESS
2. Configure prefix-SIDs for all 8 algorithms on all routers
3. Verify: `show mpls forwarding summary` — count total labels in LFIB
4. Calculate: 13 routers × 8 algorithms × 1 prefix-SID = 104 additional labels
5. **Scale question:** what's the practical limit? (SRGB size, TCAM capacity)
6. Verify: all 8 algorithms compute independent topologies
7. Document: operational complexity of managing 8+ algorithms

---

## Final Validation

By the end of this lab, your network has:

- [ ] Flex-Algo 128 defined with delay metric (low-latency slice)
- [ ] Flex-Algo 129 defined with TE metric (bandwidth-optimized slice)
- [ ] Flex-Algo 130 defined with affinity constraint (topology isolation)
- [ ] Per-algorithm prefix-SIDs configured on all participating routers
- [ ] Independent path computation verified (same dest, different path per algo)
- [ ] Link delays configured and impacting Algo 128 path selection
- [ ] Affinity-based topology pruning removing links from specific algorithms
- [ ] SR-TE policy steering traffic via algorithm-specific SIDs
- [ ] BGP color community mapping VPN traffic to Flex-Algo paths
- [ ] ODN auto-creating policies per color/algorithm combination
- [ ] 5G network slicing design documented (URLLC/eMBB/mMTC)
- [ ] Low-latency financial slice with delay bounds verified
- [ ] Disjoint redundancy planes via complementary affinity constraints
- [ ] Router participation model (join/leave algorithm by adding/removing SID)
- [ ] TI-LFA protection computed per-algorithm within constrained topology
- [ ] (CCIE+) Measurement-based delay with dynamic path adaptation
- [ ] (CCIE+) Flex-Algo definition priority and conflict resolution
- [ ] (CCIE+) Multi-algorithm scale test (8 algos, label capacity analysis)
