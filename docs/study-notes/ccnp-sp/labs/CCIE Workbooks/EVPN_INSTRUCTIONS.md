# EVPN-VXLAN Lab — Arista vEOS (Step-by-Step)

Full multipoint EVPN E-LAN on Arista vEOS. Underlay = **OSPF only (NO MPLS)** — VXLAN is the
data plane. This is the bridged EVPN (Type-2 MAC learning) that XRv 9000 could NOT do.

## Roles (from your topology)
- **CEs (5):** vEOS1, vEOS6, vEOS10, vEOS11, vEOS12  — plain L2 hosts
- **PEs (5):** vEOS2, vEOS3, vEOS5, vEOS7, vEOS8  — VTEPs (OSPF + BGP EVPN + VXLAN)
- **P (2):** vEOS4, vEOS9  — core; OSPF + BGP route-reflector only (NO VXLAN/EVI)

## Topology & links (Eth labels from diagram)
```
 vEOS1─Et1──Et1─vEOS2─Et2──Et2─vEOS3─Et1──Et1─vEOS10
                  │Et3            │Et3
                  │              vEOS5─Et1──Et1─vEOS6
                  │Et3    Et2─────┘
              ┌─vEOS4─┐  (Et2=vEOS5, Et3=vEOS2, Et4=vEOS7, Et5=vEOS8)
        Et4───┘       └───Et5
 vEOS12─Et1─Et1─vEOS7─Et4      Et5─vEOS8─Et1──Et1─vEOS11
                  │Et3            │Et2
                  └──Et3─vEOS9─Et2┘
```
| Link | A side | B side |
|------|--------|--------|
| vEOS1–vEOS2 | Et1 | Et1 (CE) |
| vEOS2–vEOS3 | Et2 | Et2 |
| vEOS2–vEOS4 | Et3 | Et3 |
| vEOS3–vEOS10 | Et1 | Et1 (CE) |
| vEOS3–vEOS5 | Et3 | Et3 |
| vEOS5–vEOS6 | Et1 | Et1 (CE) |
| vEOS5–vEOS4 | Et2 | Et2 |
| vEOS4–vEOS7 | Et4 | Et4 |
| vEOS4–vEOS8 | Et5 | Et5 |
| vEOS7–vEOS12 | Et1 | Et1 (CE) |
| vEOS7–vEOS9 | Et3 | Et3 |
| vEOS8–vEOS11 | Et1 | Et1 (CE) |
| vEOS8–vEOS9 | Et2 | Et2 |

## Addressing
| Node | Role | Lo0 (router-id) | Lo1 (VTEP) | CE-facing |
|------|------|-----------------|------------|-----------|
| vEOS2 | PE | 2.2.2.2 | 10.0.0.2 | Et1 → vEOS1 |
| vEOS3 | PE | 3.3.3.3 | 10.0.0.3 | Et1 → vEOS10 |
| vEOS5 | PE | 5.5.5.5 | 10.0.0.5 | Et1 → vEOS6 |
| vEOS7 | PE | 7.7.7.7 | 10.0.0.7 | Et1 → vEOS12 |
| vEOS8 | PE | 8.8.8.8 | 10.0.0.8 | Et1 → vEOS11 |
| vEOS4 | P/RR | 4.4.4.4 | — | — |
| vEOS9 | P/RR | 9.9.9.9 | — | — |

**Core /31 link IPs** (A = lower node number):
```
vEOS2-vEOS3 : 10.23.0.0/31 (2=.0, 3=.1)      vEOS3-vEOS5 : 10.35.0.0/31 (3=.0, 5=.1)
vEOS2-vEOS4 : 10.24.0.0/31 (2=.0, 4=.1)      vEOS5-vEOS4 : 10.45.0.0/31 (5=.0, 4=.1)
vEOS4-vEOS7 : 10.47.0.0/31 (4=.0, 7=.1)      vEOS4-vEOS8 : 10.48.0.0/31 (4=.0, 8=.1)
vEOS7-vEOS9 : 10.79.0.0/31 (7=.0, 9=.1)      vEOS8-vEOS9 : 10.89.0.0/31 (8=.0, 9=.1)
```
**Service:** VLAN 100 → VNI 10100, one E-LAN across all 5 CEs. Customer subnet 192.168.100.0/24.
**Overlay:** iBGP AS 65000; **RRs = vEOS4 + vEOS9**; clients = the 5 PEs.
> Save on Arista = `write` (or `write memory`) — NO commit model like IOS-XR. Changes apply immediately.

---

# STEP 1 — Underlay: OSPF on all 7 core nodes (PEs + Ps). NO MPLS.

### vEOS2 (PE)
```
hostname vEOS2
!
interface Loopback0
 ip address 2.2.2.2/32
interface Loopback1
 ip address 10.0.0.2/32
!
interface Ethernet2
 no switchport
 ip address 10.23.0.0/31
interface Ethernet3
 no switchport
 ip address 10.24.0.0/31
!
router ospf 1
 router-id 2.2.2.2
 network 2.2.2.2/32 area 0
 network 10.0.0.2/32 area 0
 network 10.23.0.0/31 area 0
 network 10.24.0.0/31 area 0
!
end
write
```

### vEOS3 (PE)
```
hostname vEOS3
interface Loopback0
 ip address 3.3.3.3/32
interface Loopback1
 ip address 10.0.0.3/32
interface Ethernet2
 no switchport
 ip address 10.23.0.1/31
interface Ethernet3
 no switchport
 ip address 10.35.0.0/31
router ospf 1
 router-id 3.3.3.3
 network 3.3.3.3/32 area 0
 network 10.0.0.3/32 area 0
 network 10.23.0.1/31 area 0
 network 10.35.0.0/31 area 0
end
write
```

### vEOS5 (PE)
```
hostname vEOS5
interface Loopback0
 ip address 5.5.5.5/32
interface Loopback1
 ip address 10.0.0.5/32
interface Ethernet3
 no switchport
 ip address 10.35.0.1/31
interface Ethernet2
 no switchport
 ip address 10.45.0.0/31
router ospf 1
 router-id 5.5.5.5
 network 5.5.5.5/32 area 0
 network 10.0.0.5/32 area 0
 network 10.35.0.1/31 area 0
 network 10.45.0.0/31 area 0
end
write
```

### vEOS7 (PE)
```
hostname vEOS7
interface Loopback0
 ip address 7.7.7.7/32
interface Loopback1
 ip address 10.0.0.7/32
interface Ethernet4
 no switchport
 ip address 10.47.0.1/31
interface Ethernet3
 no switchport
 ip address 10.79.0.0/31
router ospf 1
 router-id 7.7.7.7
 network 7.7.7.7/32 area 0
 network 10.0.0.7/32 area 0
 network 10.47.0.1/31 area 0
 network 10.79.0.0/31 area 0
end
write
```

### vEOS8 (PE)
```
hostname vEOS8
interface Loopback0
 ip address 8.8.8.8/32
interface Loopback1
 ip address 10.0.0.8/32
interface Ethernet5
 no switchport
 ip address 10.48.0.1/31
interface Ethernet2
 no switchport
 ip address 10.89.0.0/31
router ospf 1
 router-id 8.8.8.8
 network 8.8.8.8/32 area 0
 network 10.0.0.8/32 area 0
 network 10.48.0.1/31 area 0
 network 10.89.0.0/31 area 0
end
write
```

### vEOS4 (P / RR — central)
```
hostname vEOS4
interface Loopback0
 ip address 4.4.4.4/32
interface Ethernet3
 no switchport
 ip address 10.24.0.1/31
interface Ethernet2
 no switchport
 ip address 10.45.0.1/31
interface Ethernet4
 no switchport
 ip address 10.47.0.0/31
interface Ethernet5
 no switchport
 ip address 10.48.0.0/31
router ospf 1
 router-id 4.4.4.4
 network 4.4.4.4/32 area 0
 network 10.24.0.1/31 area 0
 network 10.45.0.1/31 area 0
 network 10.47.0.0/31 area 0
 network 10.48.0.0/31 area 0
end
write
```

### vEOS9 (P / RR — bottom)
```
hostname vEOS9
interface Loopback0
 ip address 9.9.9.9/32
interface Ethernet3
 no switchport
 ip address 10.79.0.1/31
interface Ethernet2
 no switchport
 ip address 10.89.0.1/31
router ospf 1
 router-id 9.9.9.9
 network 9.9.9.9/32 area 0
 network 10.79.0.1/31 area 0
 network 10.89.0.1/31 area 0
end
write
```

---

# STEP 2 — VERIFY underlay (all loopbacks reachable)
On any PE (e.g. vEOS2):
```
show ip ospf neighbor                 ! neighbors FULL
show ip route ospf                     ! all loopbacks (3/5/7/8/4/9) learned
ping 8.8.8.8 source 2.2.2.2            ! PE-to-PE loopback reachability (via IP, no MPLS)
ping 10.0.0.8 source 10.0.0.2          ! VTEP-to-VTEP (this is what VXLAN needs)
```
> ✅ Every VTEP loopback (10.0.0.x) reachable from every other = underlay done. NO MPLS involved.

---

# STEP 3 — Overlay: BGP EVPN (iBGP AS 65000, vEOS4+vEOS9 = RRs)

### On EACH PE (vEOS2,3,5,7,8) — example vEOS2
```
service routing protocols model multi-agent      ! REQUIRED for EVPN on Arista
!
router bgp 65000
 router-id 2.2.2.2
 no bgp default ipv4-unicast
 neighbor 4.4.4.4 remote-as 65000
 neighbor 4.4.4.4 update-source Loopback0
 neighbor 4.4.4.4 send-community extended
 neighbor 9.9.9.9 remote-as 65000
 neighbor 9.9.9.9 update-source Loopback0
 neighbor 9.9.9.9 send-community extended
 address-family evpn
  neighbor 4.4.4.4 activate
  neighbor 9.9.9.9 activate
end
write
```
> Repeat on vEOS3 (router-id 3.3.3.3), vEOS5 (5.5.5.5), vEOS7 (7.7.7.7), vEOS8 (8.8.8.8).
> Only the `router-id` changes; the two RR neighbors (4.4.4.4, 9.9.9.9) stay the same.

### On the RRs (vEOS4 and vEOS9) — example vEOS4
```
service routing protocols model multi-agent
!
router bgp 65000
 router-id 4.4.4.4
 no bgp default ipv4-unicast
 neighbor EVPN-RR-CLIENTS peer group
 neighbor EVPN-RR-CLIENTS remote-as 65000
 neighbor EVPN-RR-CLIENTS update-source Loopback0
 neighbor EVPN-RR-CLIENTS send-community extended
 neighbor EVPN-RR-CLIENTS route-reflector-client
 neighbor 2.2.2.2 peer group EVPN-RR-CLIENTS
 neighbor 3.3.3.3 peer group EVPN-RR-CLIENTS
 neighbor 5.5.5.5 peer group EVPN-RR-CLIENTS
 neighbor 7.7.7.7 peer group EVPN-RR-CLIENTS
 neighbor 8.8.8.8 peer group EVPN-RR-CLIENTS
 address-family evpn
  neighbor EVPN-RR-CLIENTS activate
end
write
```
> vEOS9 = identical, just `router-id 9.9.9.9`. (RRs reflect EVPN routes; they run NO VXLAN.)

**Verify:** `show bgp evpn summary`  → all 5 PEs Established to each RR.

---

# STEP 4 — VXLAN + EVPN service on the PEs (vEOS2,3,5,7,8 ONLY)

### On EACH PE — example vEOS2
```
vlan 100
 name CustomerA
!
interface Ethernet1
 description to CE
 switchport
 switchport mode access
 switchport access vlan 100
!
interface Vxlan1
 vxlan source-interface Loopback1
 vxlan udp-port 4789
 vxlan vlan 100 vni 10100                 ! map VLAN 100 -> VNI 10100 (SAME on all PEs)
!
router bgp 65000
 vlan 100
  rd 2.2.2.2:10100                          ! UNIQUE per PE (use own router-id)
  route-target both 10100:10100             ! SAME on all PEs -> one E-LAN
  redistribute learned
end
write
```
> Repeat on vEOS3/5/7/8. **Change only the RD** (`3.3.3.3:10100`, `5.5.5.5:10100`, etc.).
> Keep **VNI 10100** and **RT 10100:10100 identical** on all — that's what binds them into one E-LAN.
> The CE-facing port is **Et1** on every PE (per the topology).

---

# STEP 5 — CE hosts (vEOS1,6,10,11,12) — one subnet
Treat each CE as a simple host with an SVI (or a real host). Example vEOS1:
```
hostname vEOS1
vlan 100
interface Ethernet1
 switchport
 switchport mode access
 switchport access vlan 100
interface Vlan100
 ip address 192.168.100.1/24
end
write
```
| CE | IP |
|----|-----|
| vEOS1 | 192.168.100.1/24 |
| vEOS6 | 192.168.100.6/24 |
| vEOS10 | 192.168.100.10/24 |
| vEOS11 | 192.168.100.11/24 |
| vEOS12 | 192.168.100.12/24 |

---

# STEP 6 — VERIFY the EVPN-VXLAN E-LAN (the payoff)
On a PE:
```
show bgp evpn summary                       ! sessions to both RRs Established
show bgp evpn                                ! EVPN routes
show bgp evpn route-type mac-ip             ! Type-2 = CUSTOMER MACs in BGP  ← the thing XRv couldn't do!
show bgp evpn route-type imet               ! Type-3 = BUM (one per PE per VNI)
show vxlan address-table                    ! remote MACs and which VTEP they're behind
show mac address-table                      ! local + remote learned MACs
show interfaces Vxlan1                       ! VTEP up, VNI 10100 mapped
```
End-to-end (multipoint — this is the E-LAN):
```
vEOS1#  ping 192.168.100.6      ! CE1 -> CE6  (vEOS2 -> vEOS5)
vEOS1#  ping 192.168.100.11     ! CE1 -> CE11 (vEOS2 -> vEOS8, via core)
```
> ✅ SUCCESS: all 5 CEs ping each other, and `show bgp evpn route-type mac-ip` shows each CE's
> MAC learned via BGP Type-2 from the PE it sits behind. THIS is multipoint EVPN MAC learning.

---

# Troubleshooting
- **EVPN won't establish** → did you set `service routing protocols model multi-agent`? (required, and reloads the agent). Loopback reachable? `send-community extended` present?
- **No Type-2 routes** → `redistribute learned` under `router bgp / vlan 100`? VLAN-to-VNI mapping present on Vxlan1? CE port in VLAN 100?
- **CEs can't ping across** → RT must MATCH on all PEs (10100:10100); VNI must match (10100); RD must be UNIQUE per PE.
- **VXLAN down** → Loopback1 (VTEP) reachable between PEs? (`ping 10.0.0.x source 10.0.0.y`) — underlay OSPF must carry Lo1.
- **Golden rule** → if L2 breaks, re-verify STEP 2 (VTEP loopback reachability) first.

# Notes
- Underlay is **OSPF only — NO MPLS/LDP.** VXLAN (UDP 4789) is the data plane over plain IP.
- P routers (vEOS4, vEOS9) run OSPF + BGP-RR ONLY — no VXLAN, no VLAN 100, no EVI.
- Arista save = `write`. No IOS-XR commit model.
- `service routing protocols model multi-agent` is mandatory for EVPN and triggers an agent restart — do it early.
- Adjust Ethernet numbers to your real vEOS interface assignment if the lab differs from the diagram.
