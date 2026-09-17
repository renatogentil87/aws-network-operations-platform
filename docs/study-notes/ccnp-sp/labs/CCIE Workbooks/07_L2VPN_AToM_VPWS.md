# CCIE SP Workbook 07 — L2VPN: AToM / VPWS (Point-to-Point Pseudowires)

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. PEs + P + ASBRs + CEs.
**Initial configs:** Workbooks 01/03 complete — IGP + LDP, loopback LSPs between all PEs.

> **Note:** This workbook delivers Layer 2 point-to-point services (Ethernet-over-MPLS / VPWS, the E-Line product) across the core. No VRFs; the transport is the same loopback LSP mesh, now carrying a VC (pseudowire) label instead of a VPN label.

---

## Section 1 — Basic Ethernet Pseudowire

### Task 1.1
- Build an **AToM pseudowire** carrying Customer A's Layer 2 between CE1 (via PE1) and CE3 (via PE3) using **VC ID 100**.
- Use `xconnect <remote-PE-loopback> 100 encapsulation mpls` on the CE-facing interfaces.
- CE1 and CE3 must be on the same IP subnet and reach each other at Layer 2 across the core.

**Configuration**

A pseudowire emulates a wire across the MPLS core using a **two-label stack**: the outer transport label (LDP, to the remote PE loopback) tunnels the frame across the BGP-free core; the inner **VC label** identifies the specific pseudowire/attachment at the egress PE. The VC label is signaled by **targeted LDP** between the two PE loopbacks (directed LDP, not the link-local sessions). The customer frame is carried transparently — the SP does no MAC learning for a point-to-point PW; it just switches labels. This is the E-Line building block.

**Verification**
- `show mpls l2transport vc 100 detail` on PE1 — VC is `UP`, targeted LDP to PE3, imposed label stack {transport, VC}.
- `show mpls ldp neighbor` — a **targeted** LDP adjacency PE1↔PE3 exists (in addition to link-local sessions).
- CE1 ↔ CE3 ping succeeds (same subnet, Layer 2 adjacency across the core).

---

## Section 2 — Port vs VLAN Mode & Interworking

### Task 2.1
- Convert VC 100 from **port mode** (whole interface = one PW) to **VLAN mode** (one dot1q subinterface = one PW), and add a second VLAN as a separate PW to a different destination.

**Configuration**

**Port mode** (EPL — Ethernet Private Line) maps the entire physical port into one pseudowire, carrying all tags/untagged transparently like a patch cable. **VLAN mode** (EVPL — Ethernet Virtual Private Line) maps a specific dot1q VLAN to a PW, so one port can carry multiple services to different endpoints. This mirrors the MEF service distinction and lets a single access port become several independent E-Line services.

### Task 2.2
- Create a **VLAN-ID-rewrite** service: Customer A uses VLAN 100 at Site 1 but VLAN 200 at Site 2 — the PW must translate.
- (If the platform supports it) demonstrate **L2 interworking** (Ethernet↔VLAN, or IP interworking) between dissimilar attachment circuits.

**Configuration**

Because the SP strips the ingress tag and the egress applies its own, the two sites need not agree on a VLAN ID — the PW carries the payload and each end applies local encapsulation. Interworking mode goes further, bridging *dissimilar* attachment circuits (e.g., Ethernet on one side, another L2 type on the other, or IP-mode PW carrying only the L3 payload). This is what lets an SP hide access-technology differences from the customer.

**Verification**
- `show mpls l2transport vc <id> detail` — shows "local VLAN 100, remote VLAN 200" for the rewrite.
- Only the configured VLAN crosses the PW in VLAN mode; untagged/other VLANs are dropped.
- CE1 (VLAN 100) reaches CE3 (VLAN 200) at Layer 2.

---

## Section 3 — Pseudowire Redundancy

### Task 3.1
- Protect the CE1 service with a **backup pseudowire** to a second remote PE (`backup peer`), with `backup delay 0 0` for immediate switchover and restore.
- Force a failure of the primary remote attachment and measure switchover packet loss; confirm auto-restore.

**Configuration**

`backup peer` defines a standby PW to a different remote PE that activates when the primary PW goes down (detected via targeted-LDP/VCCV or AC failure). `backup delay 0 0` switches immediately and reverts immediately on recovery. This gives PE/site-level redundancy for an L2 service — the L2 equivalent of the multi-homing you built for L3VPN, and it stacks with TE-tunnel FRR (below) for layered protection.

**Verification**
- `show mpls l2transport vc <id> detail` — primary `UP/active`, backup `UP/standby`.
- Break the primary remote AC: backup goes `active`; count lost pings during switchover.
- Restore: primary re-activates, backup returns to standby.

---

## Section 4 — Multi-Segment Pseudowire (PW Switching)

### Task 4.1
- Build a **multi-segment pseudowire** from PE1 to PE6 stitched at an intermediate switching PE (e.g., P-role node acting as S-PE): segment 1 (PE1↔S-PE) + segment 2 (S-PE↔PE6), same VC ID 500.
- The S-PE stitches the two segments (`l2 vfi ... point-to-point` with two neighbors, or `connect`).

**Configuration**

Multi-segment PWs stitch two point-to-point pseudowires at a **switching PE (S-PE)**, which pops the incoming VC label and pushes the next segment's VC label — the customer frame transits untouched. This is used for inter-AS L2VPN (each SP builds its own segment, stitched at the ASBR) or to split a very long PW into independently-OAM'd segments. Each segment has its own targeted-LDP session; the S-PE needs only IP reachability + targeted LDP to its two adjacent PEs, no shared IGP across the boundary. Note: on IOS use `l2 vfi <name> point-to-point` (NOT `manual`, which is VPLS multipoint) with exactly two neighbors.

**Verification**
- `show mpls l2transport vc 500` on the S-PE — shows both segments, stitched.
- End-to-end CE1↔CE6 Layer 2 reachability across the two stitched segments.
- VCCV ping per segment isolates faults to one segment.

---

## CCIE Challenge Tasks

### Challenge A — AToM over a TE tunnel with FRR
- Steer the pseudowire onto an MPLS-TE tunnel (via `preferred-path`, or autoroute if the platform lacks it) and enable **FRR** on that tunnel. Achieve sub-50ms L2VPN protection; prove the PW never drops during a core link failure. Three protection layers: FRR → tunnel path-option → backup PW.

### Challenge B — Flow-Aware Transport (FAT) PW
- Enable a **flow label** on the pseudowire so P routers can ECMP-load-balance the flows inside a single PW across parallel core links. Explain why a plain PW is a single flow to the core.

### Challenge C — Multi-AS Carrier Ethernet
- Extend the multi-segment PW across two ASes (split the core), stitching at the ASBRs with targeted LDP only, and add a redundant second inter-AS path with a backup PW. Map the failure matrix (FRR / tunnel / inter-AS link / remote PE).
