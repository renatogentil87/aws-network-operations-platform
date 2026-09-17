# E22: NSO (Network Services Orchestrator)

**Platform:** IOS-XRv 9000 + CSR1000v + Linux NSO VM | **Topology:** `00_topology_reference.md`
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3
**Prerequisite:** E02 (L3VPN working), E14 (NETCONF enabled on all routers)
**Base:** IS-IS L2 on backbone, full loopback reachability, L3VPN operational.

**End Goal:** NSO provisions L3VPN services across all 3 SPs. Automate what you configured manually in E02.

---

### Task 1: NSO setup
1. Deploy NSO Linux VM on EVE-NG (or GNS3). Connect to management network.
2. Install NEDs: cisco-iosxr + cisco-ios (for CSR CEs).
3. Verify: `ncs --version`, `show packages` — NEDs loaded.

### Task 2: Add all devices to NSO
1. In NSO CLI: `devices device PE1 / address 1.1.1.1 / authgroup lab / device-type cli ned-id cisco-iosxr`.
2. Repeat for PE2, PE3, PE4, P2 (RR), PCE (RR), ASBR1, ASBR2.
3. Add CSR CEs: CE1-CE6 with ned-id cisco-ios.
4. `devices sync-from` — NSO pulls running config from all devices.
5. Verify: `show running-config devices device PE1` in NSO matches actual PE1.

### Task 3: L3VPN service provisioning
1. Create L3VPN service template (or use built-in if available):
   - Customer name, VRF name, RD, RT
   - PE list: PE1 (interface Gi0/0/0/0, CE1 neighbor, AS 65012)
   - PE3 (interface Gi0/0/0/2, CE4 neighbor, AS 65012)
2. `commit dry-run` — see what NSO WOULD push to PE1 and PE3.
3. `commit` — NSO pushes VRF + BGP config to both PEs simultaneously.
4. Verify: CE1 ↔ CE4 VPN works (after inter-AS from E06 is configured).

### Task 4: NSO rollback
1. `rollback configuration` — NSO removes the VRF from all devices atomically.
2. Verify: VRF gone from PE1 and PE3. CE traffic stops.
3. Re-apply → VRF returns.

### Task 5: Compliance check
1. Define golden config template for PE role (IS-IS auth, BFD timers, logging).
2. `compliance check` → NSO compares running vs golden.
3. Report deviations. Optionally auto-remediate.

### Task 6: BFD + IGP tuning via NSO template
1. Create template: enable BFD on all IS-IS interfaces (all 3 SPs).
2. Push to all 13 XRv routers in one commit.
3. Verify: `show bfd neighbors` on each — BFD UP.

### Task 7: SRv6 policy via NSO
1. Create template for SRv6-TE policy (from E21).
2. Push to PE3: SRv6-TE policy auto-deployed.
3. Verify: `show segment-routing traffic-eng policy` — active.

### Task 8: ACL deployment via NSO
1. Define infrastructure ACL (protect loopbacks from CE traffic).
2. Push to all PE routers simultaneously.
3. Verify: `show access-lists` — ACL applied.

## Checklist
```
[ ] NSO installed with NEDs (XR + IOS)
[ ] All devices synced into NSO
[ ] L3VPN provisioned via NSO across PE1 + PE3 (one commit)
[ ] Rollback works atomically
[ ] Compliance check identifies drift
[ ] BFD template pushed to all routers
[ ] SRv6 policy deployed via NSO
[ ] ACL deployed via NSO
```
