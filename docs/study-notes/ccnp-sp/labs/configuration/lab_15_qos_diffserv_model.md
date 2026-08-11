# Lab 15: QoS for Service Providers — Full DiffServ Model — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 7 CEs. Same topology as previous labs.
**Prerequisite:** Lab 1 complete (MPLS running), Lab 2 complete (L3VPN working)

**End Goal:** A complete SP QoS architecture implementing the DiffServ model end-to-end: classification at the edge, trust boundaries, DSCP-to-EXP mapping, per-hop behaviours (PHBs) in the core, and traffic contracts (policing/shaping) on customer-facing interfaces. By the end, you have the 5-6 class SP QoS model that SPCOR tests and real carriers deploy.

---

## Section 1: Classification and Marking at the SP Edge

### Task 1: Define the SP QoS Class Model

1. Design a 6-class model (standard SP deployment):

   | Class | DSCP | MPLS EXP | Description |
   |---|---|---|---|
   | Network Control | CS6 (48) | 6 | OSPF, BGP, LDP, RSVP |
   | Voice (EF) | EF (46) | 5 | Real-time voice, VoIP |
   | Video (AF41) | AF41 (34) | 4 | Interactive video, conferencing |
   | Critical Data (AF21) | AF21 (18) | 2 | Enterprise apps, databases |
   | Bulk Data (AF11) | AF11 (10) | 1 | Backups, FTP, non-interactive |
   | Best Effort | BE (0) | 0 | Internet traffic, default |

2. Document this model — it applies to the entire lab
3. **SP principle:** classify and mark ONCE at ingress, apply PHB everywhere based on marking

### Task 2: Classify Customer Traffic at PE Ingress

1. On R2 (PE) Fa0/0 (toward R1): create class-maps matching incoming DSCP:
   ```
   class-map match-any VOICE
    match dscp ef
   class-map match-any VIDEO
    match dscp af41
   class-map match-any CRITICAL-DATA
    match dscp af21
   class-map match-any BULK-DATA
    match dscp af11
   class-map match-any NETWORK-CONTROL
    match dscp cs6 cs7
   ```
2. Create a policy-map that TRUSTS customer marking (or re-marks):
   ```
   policy-map CUSTOMER-INGRESS
    class VOICE
     set dscp ef
    class VIDEO
     set dscp af41
    class CRITICAL-DATA
     set dscp af21
    class BULK-DATA
     set dscp af11
    class NETWORK-CONTROL
     set dscp cs6
    class class-default
     set dscp default
   ```
3. Apply inbound: `service-policy input CUSTOMER-INGRESS` on Fa0/0
4. Verify: `show policy-map interface Fa0/0 input` — classes matching traffic
5. On R1: generate marked traffic: `ping 9.9.9.9 tos 184` (TOS 184 = DSCP EF)
6. Verify: traffic hits the VOICE class counter

### Task 3: Trust Boundary — Don't Trust, Re-Mark

1. **Scenario:** customer sends ALL traffic marked EF (trying to get priority for everything)
2. On R2: modify CUSTOMER-INGRESS to enforce the SLA:
   - Customer contracted: 10 Mbps voice (EF), 50 Mbps data (AF21), rest is best-effort
   - Voice above 10 Mbps → remark to BE (DSCP 0)
3. Add policing to the voice class:
   ```
   policy-map CUSTOMER-INGRESS-POLICED
    class VOICE
     police rate 10000000 conform-action set-dscp-transmit ef exceed-action set-dscp-transmit default
    class CRITICAL-DATA
     police rate 50000000 conform-action set-dscp-transmit af21 exceed-action set-dscp-transmit af11
    class class-default
     set dscp default
   ```
4. Apply on Fa0/0
5. Verify: send more than 10 Mbps of EF traffic → excess gets remarked to BE
6. **SP model:** the PE ingress is the TRUST BOUNDARY. Customer markings only honored within contracted rate.

---

## Section 2: DSCP-to-EXP Mapping (PE Imposition)

### Task 4: Map DSCP to MPLS EXP at Label Imposition

1. On R2: when pushing MPLS labels, the EXP bits must reflect the DSCP:
   - Default IOS behaviour: copies IP Precedence (top 3 bits of DSCP) to EXP
   - This works for some classes but not all (AF21 = prec 2, AF41 = prec 4 — OK)
2. Verify default mapping: on R1, ping R9 with DSCP EF (prec 5):
   - On R3: `show mpls forwarding-table labels <label> detail` — check EXP of transit packet
3. If you need custom mapping (DSCP EF → EXP 5, DSCP AF41 → EXP 4, etc.):
   ```
   table-map DSCP-TO-EXP
    map from 46 to 5   ! EF → EXP 5
    map from 34 to 4   ! AF41 → EXP 4
    map from 18 to 2   ! AF21 → EXP 2
    map from 10 to 1   ! AF11 → EXP 1
    map from 48 to 6   ! CS6 → EXP 6
    default copy       ! Everything else → copy precedence
   ```
4. Apply under policy-map at label imposition (or use `mpls experimental imposition` commands)
5. Verify: `show policy-map interface` — EXP values being set correctly

### Task 5: Verify EXP in the Core

1. On R3 (P router transit): `show mpls forwarding-table` — packets passing through
2. P routers use MPLS EXP bits (not IP DSCP) to make QoS decisions
3. P routers never look inside the MPLS payload — they only see the top label + EXP
4. This is the **DiffServ advantage:** P routers do simple EXP-based QoS, no deep packet inspection
5. Verify: traffic with EXP 5 (voice) gets priority treatment on P router
6. Verify: traffic with EXP 0 (best-effort) gets default treatment

---

## Section 3: Per-Hop Behaviour (PHB) — Core Queuing

### Task 6: Configure Core Interface Queuing (P Routers)

1. On R3, all core interfaces: apply QoS output policy:
   ```
   policy-map SP-CORE-QOS
    class MPLS-EXP-6
     priority percent 5
    class MPLS-EXP-5
     priority percent 20
    class MPLS-EXP-4
     bandwidth percent 20
    class MPLS-EXP-2
     bandwidth percent 25
    class MPLS-EXP-1
     bandwidth percent 15
    class class-default
     fair-queue
   ```
2. Define class-maps based on MPLS EXP:
   ```
   class-map match-all MPLS-EXP-6
    match mpls experimental topmost 6
   class-map match-all MPLS-EXP-5
    match mpls experimental topmost 5
   class-map match-all MPLS-EXP-4
    match mpls experimental topmost 4
   class-map match-all MPLS-EXP-2
    match mpls experimental topmost 2
   class-map match-all MPLS-EXP-1
    match mpls experimental topmost 1
   ```
3. Apply output on ALL core interfaces: `service-policy output SP-CORE-QOS`
4. Verify: `show policy-map interface Gi1/0 output` — classes active
5. **Priority (LLQ):** EXP 6 (network control) and EXP 5 (voice) get strict priority — no delay, no jitter
6. **CBWFQ:** EXP 4, 2, 1 get guaranteed bandwidth — never starved, but not strict priority
7. **Default:** everything else gets whatever is left (fair-queue)

### Task 7: Verify Queuing Under Congestion

1. Generate enough traffic to cause congestion on a core link:
   - From R1: `ping 9.9.9.9 repeat 100000 size 1500 timeout 0` (flood — best-effort)
   - Simultaneously from R12: send marked traffic (if possible via different VRF)
2. On R3: `show policy-map interface Gi1/0 output` — observe:
   - Priority classes (EXP 5, 6): 0 drops
   - CBWFQ classes: may have some drops if over bandwidth allocation
   - Default class: most drops (lowest priority, gets remaining capacity)
3. Stop the flood — queues drain
4. **Key point:** QoS only matters during congestion. When links are uncongested, all traffic passes equally.

### Task 8: WRED (Weighted Random Early Detection)

1. On core interfaces, add WRED to CBWFQ classes to prevent tail-drop:
   ```
   policy-map SP-CORE-QOS
    class MPLS-EXP-2
     bandwidth percent 25
     random-detect dscp-based
    class MPLS-EXP-1
     bandwidth percent 15
     random-detect dscp-based
   ```
2. WRED proactively drops packets BEFORE queue is full — prevents global TCP synchronization
3. Verify: `show policy-map interface Gi1/0 output` — WRED drops appear (random-detect counters)
4. **Never apply WRED to voice/video (priority classes)** — those must never be randomly dropped
5. Deploy WRED on all data classes across all core interfaces

---

## Section 4: Traffic Contracts — Policing and Shaping

### Task 9: Customer Ingress Policing (Rate Enforcement)

1. Customer_A contract: 100 Mbps total, with sub-rates per class:
   - Voice: 10 Mbps (CIR)
   - Video: 20 Mbps (CIR)
   - Data: 70 Mbps (CIR)
2. On R2 Fa0/0 ingress:
   ```
   policy-map CUSTOMER-A-INGRESS
    class VOICE
     police cir 10000000 bc 312500
      conform-action set-dscp-transmit ef
      exceed-action drop
    class VIDEO
     police cir 20000000 bc 625000
      conform-action set-dscp-transmit af41
      exceed-action set-dscp-transmit af43
    class class-default
     police cir 70000000 bc 2187500
      conform-action transmit
      exceed-action set-dscp-transmit cs1
   ```
3. Voice: hard police — exceeding = DROP (can't degrade voice quality by remarking)
4. Video: exceed → remark to AF43 (lower drop priority — still delivered but first to drop in congestion)
5. Data: exceed → remark to CS1 (scavenger class — delivered but lowest priority)
6. Apply: `service-policy input CUSTOMER-A-INGRESS`
7. Verify: `show policy-map interface Fa0/0 input` — police rates enforced

### Task 10: Customer Egress Shaping (Output Rate Control)

1. On R2 Fa0/0 OUTPUT (toward R1): shape total output to customer's access rate:
   ```
   policy-map CUSTOMER-A-EGRESS
    class class-default
     shape average 100000000
     service-policy SP-CHILD-QUEUING
   ```
2. SP-CHILD-QUEUING is a hierarchical (nested) policy providing queuing WITHIN the shaped rate:
   ```
   policy-map SP-CHILD-QUEUING
    class VOICE
     priority percent 10
    class VIDEO
     bandwidth percent 20
    class CRITICAL-DATA
     bandwidth percent 30
    class class-default
     fair-queue
   ```
3. Apply: `service-policy output CUSTOMER-A-EGRESS`
4. Verify: `show policy-map interface Fa0/0 output` — shaping active with child policy
5. **Result:** customer gets exactly 100 Mbps total, with voice guaranteed within that budget
6. This is hierarchical QoS (H-QoS) — shape at parent level, queue at child level

### Task 11: Verify End-to-End QoS Path

1. On R1: send voice traffic (DSCP EF) — `ping 9.9.9.9 tos 184 repeat 1000`
2. Trace the QoS journey:
   - R2 ingress: classified, policed to 10 Mbps, DSCP EF maintained
   - R2 MPLS imposition: DSCP EF → EXP 5
   - R3 transit: EXP 5 → priority queue (LLQ) — zero drops
   - R8 egress: EXP 5 → DSCP EF restored (label disposition)
   - R8 toward R9: shaped output with voice in priority class
3. Check EACH hop: `show policy-map interface <int>` — confirm traffic hitting correct class
4. **Complete DiffServ path:** classify once, PHB at every hop, contract enforced at edges

---

## Section 5: SP QoS Design Patterns

### Task 12: EXP-to-DSCP Restoration at Egress PE

1. On R8 (egress PE) toward R9: when MPLS label is popped, restore DSCP from EXP:
   - Default: IOS copies EXP back to IP Precedence at label disposition
   - Verify: traffic that entered with DSCP EF exits with DSCP EF (or at least same precedence)
2. If custom restoration needed:
   ```
   policy-map RESTORE-DSCP
    class MPLS-EXP-5
     set dscp ef
    class MPLS-EXP-4
     set dscp af41
    class MPLS-EXP-2
     set dscp af21
   ```
3. Apply on the output toward CE
4. Verify: R9 sees correct DSCP markings on received traffic
5. **Important for SLA:** customer pays for marked delivery — must exit the SP network with correct markings

### Task 13: QoS for Network Control Traffic

1. Ensure all locally-generated routing protocol traffic is marked CS6:
   ```
   policy-map MARK-CONTROL-PLANE
    class ROUTING
     set dscp cs6
   ```
2. Apply under `control-plane` or mark in the routing process configuration
3. Verify: BGP keepalives, OSPF hellos, LDP messages all carry DSCP CS6
4. In the core: CS6 → EXP 6 → strict priority queue
5. **Why:** during congestion, routing protocol traffic must NEVER be dropped — losing BGP = losing customer VPNs
6. This is the #1 rule of SP QoS: protect the control plane above all else

### Task 14: Per-VRF QoS Differentiation

1. Customer_A pays for premium (10 Mbps voice + 90 Mbps data)
2. Customer_B pays for basic (no voice guarantee, 50 Mbps best-effort only)
3. On R2: different ingress policies per VRF interface:
   - Fa0/0 (Customer_A): full H-QoS with voice priority
   - Fa3/0 (Customer_B): simple policer, everything is best-effort, no voice class
4. Verify: Customer_A voice gets priority through the core
5. Verify: Customer_B traffic is all EXP 0 — gets best-effort treatment everywhere
6. **SP model:** QoS is a revenue differentiator — premium SLA = more $$

---

## CCIE+ Challenges

### Challenge 1: 3-Color Policing (trTCM)

1. Configure three-rate three-color marking:
   ```
   police cir 10000000 pir 15000000
    conform-action set-dscp-transmit af21
    exceed-action set-dscp-transmit af22
    violate-action set-dscp-transmit af23
   ```
2. Conform (green): within CIR → AF21 (lowest drop probability)
3. Exceed (yellow): between CIR and PIR → AF22 (medium drop)
4. Violate (red): above PIR → AF23 (highest drop — first to be WRED-dropped in core)
5. This gives graduated degradation instead of hard drop
6. Verify: different traffic rates get different AF markings

### Challenge 2: QoS Pre-Classify for Tunnels

1. On TE tunnels: traffic enters the tunnel already as MPLS — inner DSCP is hidden
2. Enable `qos pre-classify` on tunnel interface:
   - `interface Tunnel0` → `qos pre-classify`
3. This allows output QoS policy to classify based on ORIGINAL IP header (before MPLS encap)
4. Verify: QoS policy on the tunnel interface correctly identifies voice/data
5. Without pre-classify: all tunnel traffic hits class-default (can't see inner packet)

### Challenge 3: MPLS DiffServ Tunneling Modes

1. **Pipe mode:** core ignores customer DSCP. EXP set at ingress PE, restored at egress PE.
2. **Short-pipe mode:** core uses EXP. Egress PE uses original DSCP for output QoS.
3. **Uniform mode:** DSCP/EXP kept synchronized hop-by-hop.
4. Configure each mode and document the difference in behaviour
5. SP production typically uses **short-pipe** (core QoS based on EXP, customer DSCP restored at egress)
6. Verify: modify DSCP mid-path on a P router — observe what happens at egress under each mode

### Challenge 4: Complete SP QoS Deployment

1. Deploy the FULL QoS architecture simultaneously:
   - Customer ingress policing (per-class CIR enforcement) on ALL PE-CE interfaces
   - DSCP-to-EXP mapping at all ingress PEs
   - Core PHB (LLQ + CBWFQ + WRED) on ALL P router interfaces
   - EXP-to-DSCP restoration at all egress PEs
   - Customer egress H-QoS (shape + child queuing) on ALL PE-CE output
   - Control-plane traffic marked and prioritized
2. Run traffic for ALL customers simultaneously
3. Create artificial congestion on one core link
4. Verify: voice never drops, video minimally impacted, best-effort absorbs loss
5. Verify: each customer's SLA is independently maintained during congestion
6. **Congratulations:** you now have a production-grade SP QoS architecture

---

## Final Validation

By the end of this lab, your network has:

- [ ] 6-class SP QoS model defined and documented
- [ ] Classification at PE ingress matching DSCP values
- [ ] Trust boundary enforced (policing at ingress, re-marking excess)
- [ ] DSCP-to-EXP mapping at MPLS label imposition
- [ ] Core queuing (LLQ + CBWFQ) on all P router interfaces
- [ ] Priority queuing for voice/network-control (zero drops during congestion)
- [ ] WRED on data classes preventing TCP synchronization
- [ ] Customer policing enforcing contracted rates per class
- [ ] H-QoS (shape + child queue) on PE egress toward customers
- [ ] EXP-to-DSCP restoration at egress PE (customer sees correct markings)
- [ ] Network control traffic (CS6/EXP 6) prioritized above all customer traffic
- [ ] Per-VRF differentiated QoS (premium vs basic customers)
- [ ] End-to-end QoS path verified hop-by-hop
- [ ] (CCIE+) Three-color policing with graduated AF marking
- [ ] (CCIE+) QoS pre-classify for TE tunnel traffic
- [ ] (CCIE+) DiffServ tunneling modes understood (pipe, short-pipe, uniform)
- [ ] (CCIE+) Complete SP QoS deployed network-wide and proven under congestion
