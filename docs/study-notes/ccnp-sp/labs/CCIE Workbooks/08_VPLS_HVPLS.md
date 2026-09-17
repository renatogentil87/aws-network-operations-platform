# CCIE SP Workbook 08 — VPLS & H-VPLS (Multipoint L2VPN)

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology (EFP/service-instance support varies)
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. RRs: X-PE1/PE2 (AS X), Y-P1/P2 (AS Y).
**Initial configs:** IGP + LDP (Workbooks 01/03) converged.

> **Note:** VPLS delivers multipoint Layer 2 (the E-LAN product) — multiple sites on one bridged domain across the core. Requires a platform with full multipoint VFI (EVE-NG). This workbook covers LDP VPLS, BGP VPLS (auto-discovery + label blocks), and H-VPLS scaling.

---

## Section 1 — LDP VPLS (Martini)

### Task 1.1
- Create a VPLS instance (VFI) **VPLS_A, VPN ID 100** on PE1, PE3, PE5.
- Manually configure a **full mesh** of pseudowires between the three PEs (targeted LDP), bind the VFI to the customer bridge-domain/EFP.
- All three customer sites must be on one broadcast domain and learn each other's MACs.

**Configuration**

VPLS makes the SP core behave like one big Ethernet switch (a VFI = a virtual bridge per customer). Each PE MAC-learns on its attachment circuits and floods BUM traffic across the pseudowire mesh. The critical rule is **split-horizon**: a frame received on one mesh pseudowire is never forwarded to another mesh PW (only to ACs) — this prevents loops *without* STP, but it means there's no transit through a PE, so you need a **full mesh** of PWs (N×(N−1)/2). All PWs for one VPLS share the same VC ID (the VPN ID); different customers use different VC IDs.

**Verification**
- `show l2vpn bridge-domain` / `show vfi` — VFI up with the three neighbors.
- MAC table on each PE learns remote sites' MACs via the PWs.
- All three CEs ping each other at Layer 2; BUM (broadcast/ARP) reaches all sites.

---

## Section 2 — BGP VPLS (Kompella): Auto-Discovery + Signaling

### Task 2.1
- Reconfigure VPLS_A to use **BGP for both auto-discovery and signaling** (L2VPN address-family), peering PEs with RR1/RR2 instead of a manual PW mesh.
- Assign each PE a unique **VE ID**; use RD/RT like L3VPN.
- Prove that adding a new PE auto-discovers into the VPLS with no changes on existing PEs.

**Configuration**

BGP VPLS replaces manual PW config with MP-BGP (AFI L2VPN, SAFI VPLS). **Auto-discovery**: PEs advertise VPLS membership via BGP; the RT defines domain membership, so a new PE is discovered automatically by everyone importing the RT. **Signaling via label blocks**: each PE advertises a block (Label Base + VE Block Offset + size) in one BGP update; a remote PE derives its PW label as **Label Base + (its own VE ID − VE Block Offset)**. One advertisement therefore signals the pseudowires to *all* remote PEs, and it scales with route reflectors — no n² PW config, no per-neighbor touch when adding a site.

**Verification**
- `show bgp l2vpn vpls` — membership NLRIs with RD/RT and label blocks; sessions to RR1/RR2.
- Add PE-new with the same RT/VE-ID scheme; it appears in the VPLS with zero config on PE1/PE3/PE5.
- Full L2 reachability preserved; data plane identical (transport + VC label, MAC learning).

---

## Section 3 — H-VPLS (Hierarchical VPLS)

### Task 3.1
- Convert to **H-VPLS**: make PE1/PE3/PE5 the **N-PE** core (full mesh among themselves) and attach a cheap **U-PE** to PE1 via a single **spoke pseudowire** (or QinQ access).
- Prove the U-PE needs only one spoke PW (not a full mesh) and that its traffic reaches all sites via the N-PE.

**Configuration**

Flat VPLS's full PW mesh and per-PE MAC learning don't scale. H-VPLS introduces hierarchy: **N-PEs** form the full mesh; **U-PEs** (edge) attach with a single **spoke PW** to their N-PE. The enabler is that the **spoke PW is exempt from split-horizon**, so the N-PE *may* relay spoke↔mesh (which the mesh-PW rule forbids). With **QinQ access**, the U-PE can even be a plain 802.1ad switch with no MPLS — customers ride S-VLANs over one physical link to the N-PE, and the pseudowires begin at the N-PE. This concentrates cost/state on a few N-PEs and keeps the edge cheap.

**Verification**
- U-PE has exactly one spoke PW to its N-PE; N-PE bridges spoke↔mesh.
- A frame from the U-PE's customer reaches all VPLS sites (relayed by the N-PE).
- QinQ variant: U-PE runs no MPLS; N-PE maps S-VLAN → VFI.

---

## Section 4 — Scaling & Load Balancing

### Task 4.1
- Run **multiple VPLS instances** over the same physical ring/core and load-balance VLANs (odd VLANs one direction, even the other) using separate VFIs/instances.
- Discuss where the MAC-scale ceiling on the N-PEs pushes you toward EVPN (Workbook 10).

**Configuration**

Each customer/VPLS is a separate VFI with its own VC ID — you cannot share one PW across customers (that would merge broadcast domains). Multiple instances let you load-balance and segment, but every N-PE still holds a VFI + full MAC table per instance and floods BUM per instance — the flood-and-learn MAC-scale ceiling. That ceiling (plus VPLS's weak multi-homing) is exactly what motivated **EVPN**, where MACs are learned in the control plane via BGP. This section sets up the "why EVPN" transition.

**Verification**
- Multiple VFIs up; VLAN load-balancing observable in forwarding.
- MAC-table growth per instance on the N-PEs (the scaling concern).

---

## CCIE Challenge Tasks

### Challenge A — VPLS multi-homing without loops
- Dual-home a U-PE to two N-PEs with primary/backup spoke PWs and demonstrate loop-free failover (MAC withdrawal for fast convergence). Contrast with EVPN active-active.

### Challenge B — BGP-AD + LDP signaling (RFC 6074)
- Implement the hybrid: **BGP auto-discovery** with **LDP (FEC 129) signaling**. Explain when you'd pick it over full Kompella BGP VPLS.

### Challenge C — VPLS→EVPN migration
- Enable EVPN-VPLS coexistence/dual-stack on the PEs (seamless migration) and move one site to EVPN while others stay on VPLS — proving interworking. (Full EVPN in Workbook 10.)
