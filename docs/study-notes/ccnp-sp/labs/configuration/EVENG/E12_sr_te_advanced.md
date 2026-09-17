# E12: SR-TE Advanced — PCE + Flex-Algo + ODN

**Platform:** IOS-XRv 9000 | **Topology:** `00_topology_reference.md`
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3
**Prerequisite:** E04

**End Goal:** SR-PCE, stateful PCE, Flex-Algo, ODN, bandwidth-on-demand on Garnet.

---

### Task 1: SR-PCE on PCE node (17.17.17.17)
1. `pce / address ipv4 17.17.17.17 / segment-routing`. PCCs: PE3, PE4.
2. On PCCs: `segment-routing traffic-eng / pcc / source-address / pce address ipv4 17.17.17.17`.
3. Verify: `show pce ipv4 peer` — sessions from PE3/PE4.

### Task 2: Stateful PCE + delegation
1. PCE: `stateful-client / instantiation / delegate`. PCCs: `pcc / report / delegate`.
2. Verify: `show pce lsp` — all LSPs visible to PCE.
3. Delegate a policy from PE3 → PCE modifies path proactively.

### Task 3: PCE-initiated LSP
1. PCE creates tunnel on PE3 without local config. Verify on PE3: policy shows "Initiated by PCE".

### Task 4: Flex-Algo 128 (delay metric)
1. On P3 (definition source): `router isis CORE / flex-algo 128 / metric-type delay / advertise-definition`.
2. Per-algo prefix-SIDs on all Garnet routers (index +100 for algo 128).
3. Verify: `show isis flex-algo 128` — definition advertised. Independent path computation.

### Task 5: ODN + BGP color
1. `segment-routing traffic-eng / on-demand color 128 / dynamic / metric type latency / sid-algorithm 128`.
2. VPN route with color 128 arrives → policy auto-created using Algo 128. Remove → auto-deleted.

### Task 6: Redundant PCE
1. Configure PCE1 (Emerald, 5.5.5.5) as backup PCE for Garnet PCCs.
2. Failover: shut PCE → PCCs switch to PCE1. Restore → revert.

## Checklist
```
[ ] SR-PCE on PCE node; PCEP sessions from PE3/PE4
[ ] Stateful PCE: delegation, proactive path modification
[ ] PCE-initiated LSP on PE3
[ ] Flex-Algo 128 (delay metric, per-algo SIDs)
[ ] ODN: auto-create policy per BGP color
[ ] Redundant PCE failover
```
