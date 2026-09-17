# CCIE SP Workbook 10 — EVPN (Arista EVPN-VXLAN)

**Platform:** EVE-NG (Arista vEOS 4.21.1.1F)
**Topology:** Your vEOS lab — vEOS2/3/5/7/8 = PE/VTEP, vEOS4/vEOS9 = P + EVPN route reflectors, vEOS1/6/10/11/12 = CEs.
**Initial configs:** OSPF underlay converged with /32 loopbacks reachable between all VTEPs (see `EVPN_INSTRUCTIONS.md` STEP 1). **No MPLS/LDP — VXLAN is the data plane.**

> **Note:** EVPN is the modern replacement for VPLS — BGP-based MAC/IP learning, active-active multi-homing, and integrated L2/L3. On Arista the data plane is **VXLAN** (frames in UDP/IP over an OSPF core); on Cisco SP it is **MPLS**. The BGP control plane and all five route types are **identical** either way — so the concepts here transfer directly to the EVPN-MPLS tested on CCIE SP. Enable EVPN with `service routing protocols model multi-agent`; save with `write`. All work on Arista vEOS.

---

## Section 1 — EVPN Control Plane

### Task 1.1
- Configure **MP-BGP EVPN** (`address-family evpn`) between the PEs (vEOS2/3/5/7/8) and the RRs (vEOS4, vEOS9); PEs are RR clients.
- Bring up the overlay so PEs can exchange EVPN routes; underlay transport is VXLAN over the OSPF core.

**Configuration**

EVPN moves MAC learning from the data plane (VPLS flood-and-learn) into the **control plane**: PEs advertise MAC/IP reachability as BGP **Type-2** routes over the `address-family evpn`, reflected by the RRs. No full mesh and no flood-to-learn — reachability is BGP-driven, exactly like L3VPN's VPNv4. This is the single biggest change from VPLS and the foundation for everything below. On Arista, `service routing protocols model multi-agent` must be enabled first (it restarts the routing agent), and `send-community extended` is required so the RTs travel.

**Verification**
- `show bgp evpn summary` — each PE Established to vEOS4 and vEOS9, EVPN activated.
- Underlay: PE **VTEP loopbacks reachable** over OSPF (`ping <remote-VTEP> source <local-VTEP>`) for BGP next-hop resolution — no MPLS involved.

---

## Section 2 — EVPN L2 Service & Route Types

### Task 2.1
- Create the L2 service — **VLAN 100 → VNI 10100** — on all five PEs (one E-LAN for Customer A across vEOS1/6/10/11/12).
- Bring the CEs online; verify MAC learning via **Type-2** routes (not flooding) and BUM handling via **Type-3** (inclusive multicast) routes.

**Configuration**

Key EVPN route types: **Type-2 (MAC/IP)** advertises a host's MAC (and optionally IP) from the PE it is attached to — remote PEs install it without flooding. **Type-3 (Inclusive Multicast)** declares a PE's participation in the VNI and sets up BUM (broadcast/unknown/multicast) delivery (ingress replication on vEOS). **Type-1 (Ethernet Auto-Discovery)** and **Type-4 (Ethernet Segment)** appear with multi-homing (Section 3); **Type-5 (IP Prefix)** carries L3 routing (Section 4). On Arista the MAC-VRF lives under `router bgp / vlan 100` with a **unique RD per PE** and a **matching RT** — the RD keeps each PE's routes distinct in BGP, the RT binds them into one service (identical model to L3VPN). Because known MACs are advertised, EVPN floods far less than VPLS — solving VPLS's MAC-scale/flooding ceiling.

**Verification**
- `show bgp evpn route-type mac-ip` — host MAC/IP routes; local MAC = next-hop `-`, remote MAC = the origin VTEP with `Or-ID`/`C-LST` (proof it was reflected by the RR).
- `show bgp evpn route-type imet` — inclusive-multicast (Type-3), one per PE per VNI.
- `show vxlan address-table` / `show mac address-table` — remote MACs learned via BGP; CEs ping across the fabric (`vEOS1# ping 192.168.100.6`).

---

## Section 3 — Active-Active Multi-Homing

### Task 3.1
- Dual-home a CE to **two PEs** (e.g., a CE to vEOS7 **and** vEOS8) using an **Ethernet Segment (ESI)** in all-active mode.
- Verify **DF election** (Type-4), split-horizon (Type-1 ESI label), and aliasing/load-balancing to both PEs.

**Configuration**

EVPN's headline advantage over VPLS: true **all-active multi-homing** via an **Ethernet Segment Identifier (ESI)** shared by the PEs attached to the same CE/LAG (on Arista, `evpn ethernet-segment` under the Port-Channel). **Type-4 (ES route)** drives **Designated Forwarder** election — which PE forwards BUM to the segment, preventing duplicate broadcasts. **Type-1 (Ethernet A-D)** provides the ESI split-horizon label (so a PE doesn't loop BUM back to the segment) and **aliasing** (remote PEs load-balance unicast to *both* multi-homing PEs even if only one advertised the MAC), plus **mass-withdrawal** (one A-D withdrawal drops every MAC behind a failed segment → sub-second convergence). This is impossible cleanly in VPLS — it needed MC-LAG hacks.

**Verification**
- `show evpn ethernet-segment` — ESI up, DF elected, both PEs in the segment.
- `show bgp evpn route-type auto-discovery` / `route-type ethernet-segment` — Type-1 and Type-4 routes present.
- Remote PE load-balances unicast to both multi-homing PEs (aliasing); BUM only via the DF.

---

## Section 4 — EVPN IRB (Integrated Routing and Bridging)

### Task 4.1
- Add a second subnet (**VLAN 200 → VNI 10200**) and route between VLAN 100 and VLAN 200 in a tenant VRF using **symmetric IRB** with an **L3VNI**.
- Verify inter-subnet routing via **Type-5 (IP Prefix)** routes and an anycast gateway on every PE.

**Configuration**

IRB gives each subnet an **anycast gateway** (same virtual IP/MAC on every PE, via `ip address virtual` + `ip virtual-router mac-address`) so a host's default gateway is always local. **Type-2** still bridges within a subnet; **Type-5 (IP Prefix)** carries the routed prefixes between subnets. In **symmetric IRB** the ingress PE routes into a shared **L3VNI** (`vxlan vrf CUST_A vni 50000`) and the egress PE routes into the destination subnet — only the L3VNI needs to exist everywhere, so it scales better than asymmetric IRB (which needs all VNIs on all PEs). One BGP control plane carries both the L2 (Type-2) and L3 (Type-5) reachability per tenant VRF.

**Verification**
- `show bgp evpn route-type ip-prefix` — Type-5 prefixes for the tenant VRF.
- `show ip route vrf CUST_A` — remote subnets learned via EVPN.
- Host in VLAN 100 pings host in VLAN 200 (different subnet) across the fabric; gateway MAC is the local anycast MAC.

---

## Section 5 — MAC Mobility & BUM

### Task 5.1
- Move a host (or its MAC) from one PE to another and observe the **MAC mobility** sequence-number mechanism.
- Examine BUM replication mode.

**Configuration**

When a host moves PE→PE, the new PE advertises a **Type-2 with a higher MAC-mobility sequence number**; remote PEs prefer the higher sequence and the old PE withdraws its stale route — loop-free, fast host mobility that VPLS never had cleanly. BUM traffic (ARP before a MAC is known, broadcast, multicast) is delivered per Type-3: vEOS uses **head-end (ingress) replication** — the source VTEP makes one copy per remote VTEP. EVPN also does **ARP suppression** — a PE answers ARP locally from its Type-2 table, so ARP broadcasts rarely traverse the fabric.

**Verification**
- `show bgp evpn route-type mac-ip detail | include Sequence` — sequence number increments after a move.
- `show vxlan flood vtep` — the ingress-replication flood list per VNI.
- `show vxlan address-table` — the moved MAC now points at the new VTEP.

---

## Section 6 — Data Plane & CCIE-SP Bridge

### Task 6.1
- Contrast **EVPN-VXLAN** (this workbook) with **EVPN-MPLS** (CCIE SP) and confirm what transfers.

**Configuration**

Both flavors share an **identical BGP control plane and the same five route types** — only the data-plane encapsulation differs: **VXLAN** wraps frames in UDP/IP over a plain OSPF core (DC/enterprise, Arista); **EVPN-MPLS** wraps them in MPLS labels over an SR/LDP core (SP WAN, Cisco ASR9k/NCS, the CCIE SP flavor); **EVPN-SRv6** uses SRv6 SIDs. **DCI** stitches EVPN-VXLAN (DC) to EVPN-MPLS (WAN) at a border gateway. Everything you configured here — route types, RD/RT, multi-homing, IRB, MAC mobility — is the same on EVPN-MPLS; you would swap the VXLAN interface for an MPLS/EVI binding and the underlay from OSPF-only to IGP+MPLS. Concept mastery here is exam-ready for CCIE SP.

**Verification**
- Explain, from your running config, which lines are **control-plane** (BGP EVPN, RD/RT, route types — identical on MPLS) vs **data-plane** (the `interface Vxlan1` VNI mapping — the only part that becomes MPLS on Cisco).
- `show bgp evpn` — the route types you see here are exactly those an EVPN-MPLS PE would carry.

---

## Identity model (same as L3VPN)
- **VLAN→VNI (EVI)** ≈ the VRF/instance — locally significant (match by convention).
- **RD** = uniqueness per PE (unique RD → path diversity, avoids RR hiding).
- **RT** = membership — must match to share the service.
- RRs (vEOS4, vEOS9) reflect all EVPN route types (1–5), like VPNv4.

## Notes
- Underlay = **OSPF only**; VXLAN (UDP 4789) is the data plane — no MPLS/LDP on Arista EVPN-VXLAN.
- P routers (vEOS4, vEOS9) run OSPF + BGP-RR only — no VXLAN, no VLAN 100/200, no VRF.
- Enable EVPN with `service routing protocols model multi-agent`; save with `write`.
- Goal = grasp the concepts (route types, multi-homing, IRB, mobility); they are exam-identical to EVPN-MPLS — the Arista/VXLAN syntax is just the vehicle.
