# CCIE SP Workbook 12 — Service Provider QoS (DiffServ & MPLS DiffServ Tunneling)

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. PEs + P + ASBRs + CEs.
**Initial configs:** Workbooks 01/03/04 complete — IGP + LDP + at least one L3VPN so you have real customer traffic to classify.

> **Note:** This workbook implements the SP DiffServ model end-to-end: classify/mark at the PE edge (trust boundary), map to MPLS EXP in the core, apply per-hop behaviors, and manage the DiffServ tunneling modes (uniform / pipe / short-pipe) across the label stack.

---

## Section 1 — Classification & Marking at the Edge

### Task 1.1
- Define the SP class model (e.g., EF=voice, AF41=video, AF21=critical-data, default=best-effort).
- On the ingress PE, classify inbound customer traffic and **re-mark** DSCP at the trust boundary; enforce the customer's contracted rates with a **policer** (conform→transmit, exceed→re-mark to lower class).

**Configuration**

The PE ingress is the **trust boundary**: the SP does not trust customer DSCP markings beyond the contracted SLA. Traffic is classified (ACL/DSCP/NBAR) into the SP's class model and re-marked to the SP's internal DSCP/PHB. A policer enforces the contracted rate per class — conforming traffic keeps its class, exceeding traffic is re-marked down (or dropped). This protects the core from a customer marking everything EF to steal priority. MQC (class-map → policy-map → service-policy) is the framework throughout.

**Verification**
- `show policy-map interface <PE-CE>` — class hits, marking, and policer conform/exceed counters.
- Send over-rate EF from the CE: excess is re-marked to best-effort; in-contract EF is preserved.

---

## Section 2 — DSCP-to-EXP & Core PHBs

### Task 2.1
- At label imposition on the ingress PE, map the customer DSCP/PHB into the **MPLS EXP (Traffic Class)** bits.
- In the core (P routers), apply per-hop behavior (LLQ for EF, CBWFQ + WRED for AF) based on **EXP** only.

**Configuration**

P routers never see the customer IP DSCP — they see only the outer label's **EXP (3 bits, 8 classes)**. So the ingress PE must copy/map the DiffServ intent into EXP at imposition, and the core queues/drops on EXP. LLQ gives EF a strict-priority, policed queue (bounded latency for voice); CBWFQ gives AF classes bandwidth guarantees; WRED provides congestion avoidance with differentiated drop. This is how a scalable core enforces QoS with only 3 bits and no per-flow state.

**Verification**
- `show mpls forwarding-table detail` / packet capture — EXP set on the imposed labels.
- `show policy-map interface <core-link>` — LLQ/CBWFQ/WRED acting on EXP classes under congestion.

---

## Section 3 — MPLS DiffServ Tunneling Modes

### Task 3.1
- Configure and contrast the three tunneling modes across the label stack: **Uniform**, **Pipe**, and **Short-Pipe**.
- Show what happens to customer DSCP vs EXP when the core re-marks under congestion, and what the egress PE forwards to the CE in each mode.

**Configuration**

The three modes define how DiffServ markings interact between the customer IP DSCP and the MPLS EXP across the tunnel:
- **Uniform:** one integrated DiffServ domain — EXP is derived from DSCP at imposition, and any core EXP change is **copied back into DSCP** at disposition. The customer's marking can be altered by the core.
- **Pipe:** the SP's EXP is independent of customer DSCP; core re-marking affects only EXP, the **original customer DSCP is preserved** end-to-end, and the **egress PHB (to the CE) is based on the tunnel/EXP** marking.
- **Short-Pipe:** like Pipe (customer DSCP preserved, core EXP independent), but the **egress PHB is based on the customer DSCP**, not the tunnel EXP. This is the most common SP choice — the SP applies its own core QoS but hands the customer back their untouched marking and honors it on egress.

**Verification**
- Force core congestion so a P router re-marks EXP (e.g., WRED/policer), then inspect the packet leaving the egress PE:
  - Uniform: customer DSCP reflects the core change.
  - Pipe/Short-Pipe: customer DSCP unchanged; egress queue selection differs (tunnel EXP for Pipe, customer DSCP for Short-Pipe).

---

## Section 4 — Shaping, Hierarchical QoS & Scheduling

### Task 4.1
- Apply **hierarchical QoS (HQoS)** on a PE-CE sub-interface: a parent shaper to the customer's contracted rate with a child policy allocating bandwidth per class (LLQ + CBWFQ).
- Verify scheduling under congestion (priority for EF, weighted shares for AF, WRED drops for excess).

**Configuration**

HQoS nests a child (per-class) policy under a parent (aggregate shaper) so you shape the customer to their sold rate while still differentiating classes within it — essential when many sub-interfaces/EVCs share a physical port. LLQ bounds voice latency; CBWFQ gives weighted bandwidth; WRED avoids tail-drop and TCP global-sync. This is the per-customer edge QoS product that complements the EXP-based core.

**Verification**
- `show policy-map interface <subif>` — parent shaper + child class stats; priority queue served first, AF weighted, WRED dropping excess.

---

## CCIE Challenge Tasks

### Challenge A — QoS + MPLS-TE (DiffServ-TE)
- Combine class-based tunnel selection with MPLS-TE so a class (e.g., EF) rides a dedicated TE tunnel with bandwidth reservation, while best-effort uses the IGP path. Verify per-class path steering.

### Challenge B — Trust-boundary attack
- Simulate a customer marking all traffic EF; prove your ingress policer + re-mark protects the core's LLQ, then show the failure mode if the trust boundary were misconfigured.

### Challenge C — End-to-end SLA validation
- Instrument the path (IP SLA / synthetic probes) to measure per-class latency/jitter/loss under load and confirm the DiffServ design meets a voice SLA (<150 ms, low jitter). Tie the measurement (OAM/performance) back to the QoS config.
