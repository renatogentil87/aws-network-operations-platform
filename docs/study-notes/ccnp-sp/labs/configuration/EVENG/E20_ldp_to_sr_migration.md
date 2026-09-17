# E20: LDP → SR Migration (Emerald)

**Platform:** IOS-XRv 9000 | **Topology:** `00_topology_reference.md`
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3
**Prerequisite:** E01 + E03 + E04

**End Goal:** Migrate Emerald from LDP+RSVP-TE to full SR. Zero LDP. Zero RSVP. IGP + SR only.

---

### Task 1: Enable SR on Emerald alongside LDP
1. Under IS-IS on all Emerald routers: `segment-routing mpls`. Prefix-SIDs: PE1=1, PE2=2, P1=3, P2=4, ASBR1=5, PCE1=6.
2. Both LDP and SR labels exist in LFIB. Verify: `show mpls forwarding 2.2.2.2` — two entries (LDP + SR).

### Task 2: Prefer SR
1. `segment-routing mpls sr-prefer` (or under IS-IS: `address-family ipv4 / segment-routing mpls sr-prefer`).
2. Verify: SR label active, LDP label backup. Traffic uses SR.

### Task 3: Remove LDP gradually
1. Remove `mpls ldp` interface by interface (one at a time). After each: verify ping still works, LFIB still has SR labels.
2. After all removed: `show mpls ldp neighbor` — empty. SR provides all transport.

### Task 4: Enable TI-LFA (replaces RSVP-TE FRR)
1. `router isis CORE / address-family ipv4 / fast-reroute per-prefix`.
2. Verify: 100% coverage. Kill a link → sub-50ms failover. No backup tunnels needed.

### Task 5: Replace RSVP-TE tunnels with SR-TE policies
1. Remove RSVP-TE tunnel (from E03) on PE1.
2. Create equivalent SR-TE policy: `segment-routing traffic-eng / policy / candidate-paths / explicit segment-list`.
3. Verify: same path, same traffic steering. Zero RSVP state.

### Task 6: Remove RSVP entirely
1. `no mpls traffic-eng` + `no rsvp` on all Emerald routers.
2. Verify: `show rsvp interface` — empty. `show mpls traffic-eng tunnels` — empty.
3. All 3 SPs now fully SR. One protocol (IGP + SR). Zero LDP. Zero RSVP.

## Checklist
```
[ ] SR enabled alongside LDP (both labels in LFIB)
[ ] sr-prefer: SR active, LDP backup
[ ] LDP removed gradually (no outage)
[ ] TI-LFA: 100% protection, no backup tunnels
[ ] RSVP-TE tunnels replaced with SR-TE policies
[ ] RSVP removed entirely
[ ] All 3 SPs: full SR. Zero LDP. Zero RSVP.
```
