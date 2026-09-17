# CCIE SP Workbook 01 — IS-IS Foundation

**Domain:** Core Routing (25% of CCIE SP lab)
**Platform:** IOS-XRv 9000 on GNS3/EC2
**Topology:** `../../configuration/EVENG/00_topology_reference.md` — Emerald AS 65100 + Gold AS 65300 + Garnet AS 65200 (3 ISPs)
**Format:** ccielabpass DOO — every task is **Question → Solution → Verification**

> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3 (NIC0/NIC1 = internal/mgmt)

---

## Topology Quick-Reference (used by every task)

### Node inventory + NET-ID derivation

NET-ID format: `49.<area>.<system-id>.00`. The **system-id** is derived from the Loopback0 IPv4 address by padding each octet to 3 digits and regrouping into three 4-hex-digit blocks (the classic "IP-to-NET" method).

Example — PE1 Loopback0 `1.1.1.1` → `001.001.001.001` → `0010.0100.1001`.

| SP (area) | Node | Role | Loopback0 | Derived NET-ID |
|-----------|------|------|-----------|----------------|
| **Emerald** 49.0001 | PE1 | PE | 1.1.1.1 | `49.0001.0010.0100.1001.00` |
| | PE2 | PE | 2.2.2.2 | `49.0001.0020.0200.2002.00` |
| | P1 | P | 3.3.3.3 | `49.0001.0030.0300.3003.00` |
| | P2 | P | 4.4.4.4 | `49.0001.0040.0400.4004.00` |
| | ASBR1 | ASBR | 5.5.5.5 | `49.0001.0050.0500.5005.00` |
| | PCE1 | RR+PCE | 6.6.6.6 | `49.0001.0060.0600.6006.00` |
| **Garnet** 49.0002 | PE3 | PE | 11.11.11.11 | `49.0002.0110.1101.1011.00` |
| | PE4 | PE | 12.12.12.12 | `49.0002.0120.1201.2012.00` |
| | P3 | P | 13.13.13.13 | `49.0002.0130.1301.3013.00` |
| | P4 | P | 14.14.14.14 | `49.0002.0140.1401.4014.00` |
| | P5 | P | 15.15.15.15 | `49.0002.0150.1501.5015.00` |
| | ASBR2 | ASBR | 16.16.16.16 | `49.0002.0160.1601.6016.00` |
| | PCE | RR+PCE | 17.17.17.17 | `49.0002.0170.1701.7017.00` |
| **Gold** 49.0003 | ASBR3 | ASBR+RR+PCE | 21.21.21.21 | `49.0003.0210.2102.1021.00` |
| | ASBR4 | ASBR | 22.22.22.22 | `49.0003.0220.2202.2022.00` |
| | P6 | P | 23.23.23.23 | `49.0003.0230.2302.3023.00` |
| | PE5 | PE | 24.24.24.24 | `49.0003.0240.2402.4024.00` |
| | PE6 | PE | 25.25.25.25 | `49.0003.0250.2502.5025.00` |

### Per-router core (IS-IS) interfaces — from the link map

| SP | Node | Core Gi interfaces (run IS-IS) | Non-core (NO IS-IS) |
|----|------|--------------------------------|---------------------|
| Emerald | PE1 | Gi0/0/0/2 (→P1), Gi0/0/0/3 (→PE2) | Gi0/0/0/0 (CE1), Gi0/0/0/1 (CE2) |
| Emerald | PE2 | Gi0/0/0/0 (→P1), Gi0/0/0/3 (→PE1) | Gi0/0/0/1 (CE2), Gi0/0/0/2 (CE3) |
| Emerald | P1 | Gi0/0/0/0 (→PE2), Gi0/0/0/1 (→P2), Gi0/0/0/2 (→PE1) | — |
| Emerald | P2 | Gi0/0/0/1 (→P1), Gi0/0/0/2 (→ASBR1), Gi0/0/0/3 (→PCE1) | — |
| Emerald | ASBR1 | Gi0/0/0/2 (→P2) | Gi0/0/0/1 (inter-AS Garnet), Gi0/0/0/3 (inter-AS Gold) |
| Emerald | PCE1 | Gi0/0/0/3 (→P2) | — |
| Garnet | PE3 | Gi0/0/0/1 (→P4), Gi0/0/0/3 (→PE4) | Gi0/0/0/2 (CE4), Gi0/0/0/0 (CE5) |
| Garnet | PE4 | Gi0/0/0/2 (→P5), Gi0/0/0/3 (→PE3) | Gi0/0/0/1 (CE5), Gi0/0/0/0 (CE6) |
| Garnet | P3 | Gi0/0/0/0 (→P4), Gi0/0/0/1 (→P5), Gi0/0/0/2 (→ASBR2), Gi0/0/0/3 (→PCE) | — |
| Garnet | P4 | Gi0/0/0/0 (→P3), Gi0/0/0/1 (→PE3), Gi0/0/0/3 (→P5) | — |
| Garnet | P5 | Gi0/0/0/1 (→P3), Gi0/0/0/2 (→PE4), Gi0/0/0/3 (→P4) | — |
| Garnet | ASBR2 | Gi0/0/0/2 (→P3) | Gi0/0/0/1 (inter-AS Emerald), Gi0/0/0/3 (inter-AS Gold) |
| Garnet | PCE | Gi0/0/0/3 (→P3) | — |
| Gold | ASBR3 | Gi0/0/0/1 (→P6), Gi0/0/0/2 (→ASBR4) | Gi0/0/0/3 (inter-AS Emerald) |
| Gold | ASBR4 | Gi0/0/0/0 (→P6), Gi0/0/0/2 (→ASBR3) | Gi0/0/0/3 (inter-AS Garnet) |
| Gold | P6 | Gi0/0/0/0 (→ASBR4), Gi0/0/0/1 (→ASBR3), Gi0/0/0/2 (→PE5), Gi0/0/0/3 (→PE6) | — |
| Gold | PE5 | Gi0/0/0/2 (→P6) | Gi0/0/0/0 (CE9), Gi0/0/0/1 (CE8) |
| Gold | PE6 | Gi0/0/0/3 (→P6) | Gi0/0/0/0 (CE7), Gi0/0/0/1 (CE8) |

### Core link subnets (for interface addressing)

| SP | Link | Subnet | Addresses |
|----|------|--------|-----------|
| Emerald | PCE1(Gi3)–P2(Gi3) | 10.1.1.0/24 | PCE1 .6, P2 .4 |
| Emerald | P2(Gi2)–ASBR1(Gi2) | 10.1.2.0/24 | P2 .4, ASBR1 .5 |
| Emerald | P2(Gi1)–P1(Gi1) | 10.1.3.0/24 | P2 .4, P1 .3 |
| Emerald | P1(Gi2)–PE1(Gi2) | 10.1.4.0/24 | P1 .3, PE1 .1 |
| Emerald | P1(Gi0)–PE2(Gi0) | 10.1.5.0/24 | P1 .3, PE2 .2 |
| Emerald | PE1(Gi3)–PE2(Gi3) | 10.1.6.0/24 | PE1 .1, PE2 .2 |
| Garnet | PCE(Gi3)–P3(Gi3) | 10.2.1.0/24 | PCE .17, P3 .13 |
| Garnet | ASBR2(Gi2)–P3(Gi2) | 10.2.2.0/24 | ASBR2 .16, P3 .13 |
| Garnet | P3(Gi0)–P4(Gi0) | 10.2.3.0/24 | P3 .13, P4 .14 |
| Garnet | P3(Gi1)–P5(Gi1) | 10.2.4.0/24 | P3 .13, P5 .15 |
| Garnet | P4(Gi3)–P5(Gi3) | 10.2.5.0/24 | P4 .14, P5 .15 |
| Garnet | P4(Gi1)–PE3(Gi1) | 10.2.6.0/24 | P4 .14, PE3 .11 |
| Garnet | P5(Gi2)–PE4(Gi2) | 10.2.7.0/24 | P5 .15, PE4 .12 |
| Garnet | PE3(Gi3)–PE4(Gi3) | 10.2.8.0/24 | PE3 .11, PE4 .12 |
| Gold | ASBR3(Gi2)–ASBR4(Gi2) | 10.3.1.0/24 | ASBR3 .21, ASBR4 .22 |
| Gold | ASBR3(Gi1)–P6(Gi1) | 10.3.2.0/24 | ASBR3 .21, P6 .23 |
| Gold | ASBR4(Gi0)–P6(Gi0) | 10.3.3.0/24 | ASBR4 .22, P6 .23 |
| Gold | P6(Gi2)–PE5(Gi2) | 10.3.4.0/24 | P6 .23, PE5 .24 |
| Gold | P6(Gi3)–PE6(Gi3) | 10.3.5.0/24 | P6 .23, PE6 .25 |

> **IPv6 core convention (Task 1.5):** mirror the IPv4 subnet as `2001:db8:1:X::/64` (Emerald), `2001:db8:2:X::/64` (Garnet), `2001:db8:3:X::/64` (Gold), host bits = the router's loopback octet. Loopback0 IPv6 = `2001:db8::<loop>/128` (e.g., PE1 = `2001:db8::1/128`).

---

# Section 1 — IS-IS Basic Setup (8 tasks)

---

## Task 1.1 — Enable IS-IS L2-only on all Emerald routers

### Question
Configure IS-IS process **CORE** as **Level-2-only** on all six Emerald routers (PE1, PE2, P1, P2, ASBR1, PCE1). Derive each NET-ID from the router's Loopback0 (`49.0001.xxxx.xxxx.xxxx.00`). Use **metric-style wide**. Run IS-IS on Loopback0 and the core interfaces only (see the per-router table); do **not** enable it on PE-CE or inter-AS interfaces.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 1.2 — Enable IS-IS L2-only on all Garnet routers

### Question
Same as 1.1 but for the seven Garnet routers (PE3, PE4, P3, P4, P5, ASBR2, PCE) using area **49.0002**. NET-ID derived from Loopback0, `metric-style wide`, core interfaces only.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 1.3 — Enable IS-IS L2-only on all Gold routers

### Question
Same pattern for the five Gold routers (ASBR3, ASBR4, P6, PE5, PE6), area **49.0003**.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 1.4 — CCIE-ISIS flexible configuration group (regex interface matching)

### Question
Rather than repeat interface knobs on every router, build a **flexible CLI configuration group** named `CCIE-ISIS` that, via a **regex** matching all `GigabitEthernet` interfaces under `router isis CORE`, applies: L2 metric **200** (IPv4) and **400** (IPv6), **hello-padding disable**, **point-to-point**; and, matching `Loopback`, sets **passive**. Apply the group and confirm the inherited config.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 1.5 — IPv6 address-family with single-topology (all 3 IS-IS instances)

### Question
Enable the **IPv6 unicast** address-family in all three `router isis CORE` instances using **single-topology** (IPv6 shares the IPv4 SPF/topology). Add IPv6 addressing on Loopback0 and all core interfaces. Show the config on one router per SP; the pattern repeats.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 1.6 — set-overload-bit on-startup 180 level-2 (all routers)

### Question
On **every** router in all three SPs, set the IS-IS overload bit on startup for **180 seconds** at **level-2**, so the node is not used as transit until it has fully converged (BGP, LDP/SR, LSDB). Show the config; it is identical on all nodes.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 1.7 — LDP auto-config under IS-IS (Emerald only)

### Question
Emerald uses **LDP** for transport (Gold=SRv6, Garnet=SR-MPLS — no LDP there). Enable **LDP IGP auto-config** under the Emerald IS-IS instance so LDP is enabled automatically on every IS-IS core interface. Configure MPLS LDP on the six Emerald routers.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 1.8 — LDP–IGP synchronization (Emerald)

### Question
Prevent traffic blackholing when an LDP session is down but the IS-IS adjacency is up: enable **LDP–IGP synchronization** at **level-2** on Emerald. Until LDP synchronizes on a link, IS-IS should advertise that link with **max metric** so it isn't used as a labeled transit path.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 2.1 — IS-IS authentication (key-chain, HMAC-MD5), per-level + per-interface (Emerald)

### Question
Secure Emerald IS-IS with **HMAC-MD5** authentication using a **key-chain**. Apply authentication two ways: **per-level** (LSP/SNP authentication for the whole L2 domain) and **per-interface** (hello authentication on a specific link). All Emerald routers must share the key.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 2.2 — IS-IS prefix suppression on core P-P links

### Question
Reduce the LSDB and speed SPF by **suppressing transit (P-to-P core link) prefixes** from IS-IS — advertise only loopbacks. Configure prefix suppression on all routers (global) and confirm core /24s no longer appear as IS-IS routes, while loopbacks still do.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 2.3 — Multi-topology vs single-topology (explain + configure single)

### Question
Explain **when** to use IS-IS multi-topology (MT) versus single-topology, then confirm all three instances run **single-topology** (as set in Task 1.5).


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 2.4 — Route leaking between levels (concept — N/A for L2-only)

### Question
Explain IS-IS inter-level **route leaking**, why it exists, and why it is **not applicable** in this lab (everything is Level-2-only).


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 2.5 — IS-IS BFD for fast adjacency failure detection (all core links)

### Question
Enable **BFD** for IS-IS on all core links in all three SPs so link/neighbor failures are detected in milliseconds instead of waiting for IS-IS hold timers. Use 300 ms intervals, multiplier 3 (≈900 ms detection).


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 2.6 — IS-IS mesh-group on fully-meshed segments (reduce flooding)

### Question
On a **fully-meshed** set of routers, LSP flooding is redundant (every router floods to every neighbor). Configure an IS-IS **mesh-group** to suppress redundant flooding. Apply it to the Emerald PE1–PE2–P1 near-mesh (PE1↔PE2, PE1↔P1, PE2↔P1 all adjacent).


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 3.1 — Full verification checklist

### Question
Produce a repeatable IS-IS health-check using the four core show commands and state what "good" looks like for each.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 3.2 — Troubleshooting: adjacency stuck in INIT

### Question
An IS-IS adjacency will not reach `Up` — it sits in **`Init`** (or flaps). Diagnose the three classic causes: **MTU mismatch**, **area/level mismatch**, **authentication mismatch**. Show how to identify and fix each.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 3.3 — Troubleshooting: routes not appearing

### Question
Adjacencies are `Up` but some prefixes are missing from the routing table. Diagnose the two classic causes: **passive-interface misconfiguration** and a **core interface missing from IS-IS**.


> *Try this yourself first. Solution available in `solutions/` folder.*

## Task 3.4 — IS-IS convergence timing (SPF / LSP intervals, sub-second tuning)

### Question
Tune IS-IS for **sub-second convergence**: exponential **SPF backoff**, **LSP generation** backoff, and **LSP flooding/refresh** timers. Explain each timer and give an aggressive-but-stable set for the lab core.


> *Try this yourself first. Solution available in `solutions/` folder.*

