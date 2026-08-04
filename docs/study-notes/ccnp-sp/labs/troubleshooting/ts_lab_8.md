# Troubleshooting Lab 8: QoS in SP Networks — 20 Tickets

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 12 routers — 4 PEs (R1, R4, R7, R10), 4 P routers, 4 CEs (traffic generators)
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change IGP or MPLS configuration unless explicitly required
- Do NOT add new interfaces or IP addresses unless explicitly required
- Do NOT remove existing features to resolve a ticket — fix the root cause
- Static routes are NOT permitted unless preconfigured
- Points are awarded for finding AND resolving the fault
- The resolution of one ticket MAY depend on previous tickets
- There are NO physical faults (all interfaces are cabled correctly)
- Use password `cisco` for any authentication if needed

---

## Topology Reference

| Role | Routers |
|---|---|
| PE (ingress) | R1, R10 |
| PE (egress) | R4, R7 |
| P (core) | R2, R3, R5, R6 |
| CE (traffic gen) | R20 (VoIP), R21 (Video), R22 (Data), R23 (Best-effort) |

**QoS Model:**
- 6 classes: EF (voice), AF41 (video), AF21 (critical data), AF11 (bulk data), CS6 (network control), Default (best-effort)
- Core: MPLS EXP-based QoS (short-pipe model)
- Edge: DSCP classification and marking at PE ingress
- Per-hop: Strict priority for EF, CBWFQ for AF classes, Default WFQ

**Bandwidth:** Core links 100 Mbps, PE-CE links 10 Mbps
**Congestion:** Simulated via traffic generators exceeding link capacity

---

## Ticket 1

Voice traffic (DSCP EF) from R20 is entering R1 but is NOT being placed into the priority queue on R1's core-facing interface. All traffic exits R1 in the default queue. The class-map matching EF exists but the policy-map is not applied.

Fix the network so that EF traffic enters the priority queue on R1's egress.

Verify: `show policy-map interface <core-facing>` on R1 shows packets matching the EF class and being queued in the priority queue.

Score: 2 Points

---

## Ticket 2

Video traffic (DSCP AF41) is being correctly classified at the PE ingress but the MPLS EXP bits are NOT being set in the imposed label. Traffic enters the core with EXP=0 (best-effort) regardless of the original DSCP value.

Fix the network so that DSCP-to-EXP mapping occurs at the PE during label imposition.

Verify: `show policy-map interface` on R1 shows traffic being marked. On the core-facing interface, MPLS packets carry the correct EXP value corresponding to AF41.

Score: 2 Points

---

## Ticket 3

The priority queue (EF/voice) on a P router's interface is configured with a policer (rate-limit) of 1 Mbps, but voice traffic is only 200 kbps. Despite being well under the policer limit, voice packets are being dropped by the policer.

Fix the network so that voice traffic within the policer rate is forwarded without drops.

Verify: `show policy-map interface` on the P router shows 0 drops for EF class while traffic is under the rate limit. Voice quality is acceptable (no drops).

Score: 2 Points

---

## Ticket 4

WRED (Weighted Random Early Detection) is configured on the AF21 class to provide early congestion notification. However, during congestion, AF21 traffic is being tail-dropped instead of experiencing WRED drops. The WRED profile shows 0 random drops and increasing tail drops.

Fix the network so that WRED actively manages the AF21 queue before it fills completely.

Verify: `show policy-map interface` — AF21 class shows WRED random drops (non-zero) during congestion with 0 tail drops.

Score: 3 Points

---

## Ticket 5

The ingress PE (R1) is performing DSCP re-marking on ALL traffic, not just traffic that exceeds the committed rate. Traffic within the contracted rate (CIR) should maintain its original DSCP. Only excess traffic should be re-marked to a lower DSCP.

Fix the network so that conforming traffic retains its DSCP and only exceeding traffic is re-marked.

Verify: `show policy-map interface <CE-facing>` — conform action is transmit (no re-mark), exceed action is set-dscp to lower value. Voice within CIR keeps DSCP EF.

Score: 3 Points

---

## Ticket 6

Network control traffic (DSCP CS6 — OSPF, LDP, BGP keepalives) is being dropped during heavy congestion on a core link. The QoS policy has classes for customer traffic but no protection for network control plane packets.

Fix the network so that network control traffic (CS6) is protected during congestion.

Verify: During congestion simulation, `show policy-map interface` shows CS6 class with 0 drops. OSPF adjacencies remain stable during congestion.

Score: 3 Points

---

## Ticket 7

Short-pipe model: At the egress PE (R4), traffic exits the MPLS domain but the penultimate-hop PHP (Penultimate Hop Popping) causes the EXP bits to be lost before the egress PE can classify. The egress PE sees all traffic as best-effort regardless of the original marking.

Fix the network so that the egress PE can classify traffic correctly after PHP.

Verify: `show policy-map interface <CE-facing>` on R4 shows traffic distributed across correct classes (EF, AF41, etc.) based on the original DSCP preserved beneath the MPLS header.

Score: 2 Points

---

## Ticket 8

Hierarchical QoS (H-QoS) on the PE-CE interface: A parent shaper limits total customer traffic to 5 Mbps, with child policies allocating bandwidth to each class within that shaped rate. The parent shaper is working but all child classes show 0% bandwidth allocation — traffic within the shaped rate is not being differentiated.

Fix the network so that the child policy correctly differentiates traffic classes within the shaped parent rate.

Verify: `show policy-map interface` — parent shows shaping to 5 Mbps, child shows bandwidth allocation per class with active queuing during congestion within the shaped rate.

Score: 3 Points

---

## Ticket 9

Two-rate three-color marking (trTCM) is configured for the AF21 class. Traffic should be marked green (conform/AF21), yellow (exceed/AF22), or red (violate/AF23). However, all traffic is being marked red regardless of rate. The policer burst sizes appear to be set to 0.

Fix the network so that the three-color policer correctly marks traffic as green/yellow/red based on measured rates.

Verify: `show policy-map interface` — AF21 class shows traffic distributed across conform, exceed, and violate actions based on traffic rate relative to CIR/PIR.

Score: 2 Points

---

## Ticket 10

MPLS EXP-based queuing on a P router is ignoring EXP values. The class-map uses `match mpls experimental topmost` but all traffic falls into the default class. MPLS traffic with different EXP values is transiting but not being differentiated.

Fix the network so that the P router classifies MPLS traffic based on EXP bits.

Verify: `show policy-map interface` — traffic distributes across EXP-based classes. EF (EXP 5) goes to priority queue, AF (EXP 3-4) to CBWFQ classes.

Score: 2 Points

---

## Ticket 11

Traffic shaping at the PE egress (toward CE) is configured for 10 Mbps but is only passing 5 Mbps. The interface is physically 100 Mbps. The shaper configuration shows the correct rate but actual throughput is exactly half.

Fix the network so that the shaper allows the full 10 Mbps to the CE.

Verify: Traffic generator pushes 10 Mbps — all passes through. `show policy-map interface` shows shape rate of 10 Mbps with no excess drops at that rate.

Score: 3 Points

---

## Ticket 12

QoS pre-classify is needed for TE tunnel traffic. VPN traffic entering a TE tunnel is losing its original DSCP classification because the tunnel encapsulation happens before QoS policy evaluation. All traffic exits the tunnel interface as best-effort.

Fix the network so that QoS classification occurs on the original packet headers before tunnel encapsulation.

Verify: `show policy-map interface Tunnel0` shows traffic matched by original DSCP values. Correct per-class queuing within the tunnel.

Score: 3 Points

---

## Ticket 13

Per-VRF QoS: Two VPN customers share the same PE egress interface but have different SLA requirements. Customer_A (VRF_A) should get strict 5 Mbps guaranteed; Customer_B (VRF_B) gets best-effort only. Currently both customers are treated identically.

Fix the network so that per-VRF QoS differentiates treatment on the shared egress interface.

Verify: During congestion, Customer_A maintains its 5 Mbps guarantee while Customer_B traffic is degraded. `show policy-map interface` shows per-VRF class counters.

Score: 4 Points

---

## Ticket 14

ECN (Explicit Congestion Notification): WRED is configured with ECN enabled for TCP traffic. During congestion, TCP flows should receive ECN marks (CE codepoint) instead of drops for early congestion notification. However, ECN-capable packets are being dropped instead of marked.

Fix the network so that ECN-capable TCP traffic is ECN-marked during early congestion instead of dropped.

Verify: `show policy-map interface` — ECN marking counter is non-zero during congestion. TCP throughput improves compared to drop-based congestion management.

Score: 4 Points

---

## Ticket 15

Policer cascade: The PE has an ingress aggregate policer (total customer rate) AND per-class policers (individual class rates). The aggregate should be checked FIRST, then per-class. Currently the per-class policers fire first, and their sum exceeds the aggregate — resulting in the aggregate dropping traffic that individual class policers already admitted.

Fix the network so that the policer hierarchy operates in the correct order (aggregate first, then per-class).

Verify: `show policy-map interface` — aggregate policer conformance rate equals sum of per-class admitted rates. No double-drop scenario.

Score: 4 Points

---

## Ticket 16

QoS propagation across MPLS VPN: A customer sends traffic marked DSCP EF from CE1, it traverses the SP backbone, and arrives at CE2 with DSCP 0 (best-effort). The MPLS core QoS works (EXP bits set correctly) but the final DSCP value is being zeroed at egress.

Fix the network so that the customer's original DSCP marking is preserved end-to-end across the MPLS VPN.

Verify: CE2 receives traffic with the original DSCP EF marking. `show policy-map interface` on egress PE shows correct DSCP in egress packets.

Score: 4 Points

---

## Ticket 17

Scheduling starvation: The priority queue (EF/voice) is configured without a policer/rate-limit. A traffic burst of EF-marked traffic (possibly mis-marked by the customer) is consuming ALL interface bandwidth, starving all other classes including network control (CS6). OSPF adjacency drops during the burst.

Fix the network so that the priority queue is bounded and cannot starve other classes.

Verify: During an EF traffic burst exceeding the policer rate, `show policy-map interface` shows EF traffic being policed. Other classes continue to receive their allocated bandwidth. OSPF remains stable.

Score: 4 Points

---

## Ticket 18

Complete QoS failure on a P router link: ALL traffic is being treated as best-effort despite QoS policies being configured and applied. `show policy-map interface` shows the policy active with class definitions, but ALL packets match the default class (class-default) — zero packets in any specific class.

Fix the network so that MPLS-based classification works and traffic distributes across the configured classes.

Verify: `show policy-map interface` — each class shows non-zero packet matches corresponding to the traffic mix. Priority, CBWFQ, and WRED all active.

Score: 5 Points

---

## Ticket 19

QoS interaction with fragmentation: Large packets (>1500 bytes from the CE) entering the MPLS core are being fragmented, and only the first fragment retains the correct EXP marking. Subsequent fragments are marked EXP 0 (best-effort), causing voice quality issues when large data packets fragment across the same path.

Fix the network so that QoS is consistent across all fragments OR fragmentation is prevented while maintaining service.

Verify: All traffic (including large frames) receives consistent QoS treatment end-to-end. No fragments with mismatched EXP bits. Voice quality (jitter, loss) meets SLA.

Score: 5 Points

---

## Ticket 20

Multi-class failure:
- EF (voice): Priority queue drops despite being under rate limit (policer misconfiguration)
- AF41 (video): Correct classification but wrong queue (shares with best-effort)
- AF21 (data): WRED configured but thresholds inverted (drops start at min instead of approaching max)
- CS6 (control): Not classified at all on two P routers
- Default: Receives zero bandwidth allocation (starvation under load)

Fix ALL five QoS class issues simultaneously.

Verify: `show policy-map interface` on affected routers shows correct behavior for all classes. Voice lossless under rate, video queued correctly, data WRED normal, control protected, default gets fair share.

Score: 5 Points

---

## Scoring Summary

| Tickets | Difficulty | Points Each | Total |
|---|---|---|---|
| 1-3 | CCNP-SP (⭐⭐) | 2 | 6 |
| 4-6 | CCNP-SP (⭐⭐⭐) | 3 | 9 |
| 7-9 | CCNP-SP (⭐⭐⭐) | 2-3 | 7 |
| 10-12 | CCNP→CCIE (⭐⭐⭐) | 2-3 | 8 |
| 13-17 | CCIE-SP (⭐⭐⭐⭐) | 4 | 20 |
| 18-20 | CCIE-SP (⭐⭐⭐⭐⭐) | 5 | 15 |
| **Total** | | | **65 Points** |

**Passing:** 49/65 (75%)
**CCIE-ready:** 59/65 (90%)
