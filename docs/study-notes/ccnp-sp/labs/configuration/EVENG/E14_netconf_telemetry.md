# E14: NETCONF/YANG + Telemetry

**Platform:** IOS-XRv 9000 + CSR1000v | **Topology:** `00_topology_reference.md`
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3
**Prerequisite:** E02

**End Goal:** Model-driven programmability — NETCONF, gRPC telemetry, RESTCONF.

---

### Task 1: Enable NETCONF on all XRv (port 830)
1. `ssh server v2 / ssh server netconf vrf default / netconf-yang agent ssh`. Test SSH to port 830.

### Task 2: Python ncclient — get-config / edit-config / commit
1. `get-config` interfaces from PE1. Parse XML. `edit-config` create Loopback100. `commit`. Delete it.

### Task 3: Push VRF via NETCONF
1. Push complete L3VPN VRF to PE3 via NETCONF XML. Verify `show vrf`. No CLI used.

### Task 4: gRPC telemetry — dial-out
1. `grpc / port 57400 / no-tls` on PE1. Sensor-group (interface counters), subscription 10s → collector.
2. Verify: data streams arrive every 10 seconds.

### Task 5: gNMI subscribe — dial-in
1. Subscribe to `/bgp/neighbors/neighbor/state` on PE1 (sample 5s). Kill BGP session → observe state change real-time.

### Task 6: RESTCONF on CSR CEs
1. On CE3 (CSR1000v): `restconf / ip http secure-server`. GET interfaces via curl. PUT to modify.

## Checklist
```
[ ] NETCONF on all XRv (port 830, get-config/edit-config/commit)
[ ] VRF provisioned via NETCONF (no CLI)
[ ] gRPC dial-out telemetry (10s counters)
[ ] gNMI dial-in (BGP state changes)
[ ] RESTCONF on CSR CEs
```
