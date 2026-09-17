# E05: L2VPN — AToM + EVPN-VPWS

**Platform:** IOS-XRv 9000 on GNS3/EC2
**Topology:** `00_topology_reference.md` — Emerald AS 65100 (AToM/LDP) + Garnet AS 65200 (EVPN/SR)
> **NIC Mapping:** NIC2=Gi0/0/0/0, NIC3=Gi0/0/0/1, NIC4=Gi0/0/0/2, NIC5=Gi0/0/0/3
**Prerequisite:** E01 complete (LDP on Emerald, SR on Garnet).

**End Goal:** AToM pseudowire PE1↔PE2 (targeted LDP, control word, backup PW using CE2 dual-homing) on Emerald; EVPN-VPWS PE3↔PE4 on Garnet. Compare LDP-signalled vs BGP-signalled L2VPN.

---

## Section 1: AToM on Emerald (LDP-signalled PW)

### Task 1: Attachment circuits
1. Choose L2 sub-interfaces / ports toward CE1 (PE1) and CE2 (PE2) as ACs (e.g., `l2transport`).
2. Verify: `show interfaces <ac> | i line protocol` — ACs UP.

### Task 2: Targeted LDP + xconnect PE1↔PE2
1. `l2vpn / xconnect group EMERALD / p2p PW1` with `interface <ac>` + `neighbor ipv4 2.2.2.2 pw-id 100` (mirror on PE2 → 1.1.1.1).
2. Targeted LDP session forms between PE1↔PE2 loopbacks.
3. Verify: `show l2vpn xconnect` — state UP.
4. Verify: `show mpls ldp neighbor 2.2.2.2` — targeted (tLDP) session present.

### Task 3: Control word
1. Enable control word under the `pw-class` used by the PW.
2. Verify: `show l2vpn xconnect detail` — "Control word enabled" on both ends.

### Task 4: Backup PW (exploit CE2 dual-homing)
1. On PE1, add `backup neighbor ipv4 <second-PE> pw-id 100` for the same p2p (CE2 is reachable via PE1 and PE2).
2. Verify: `show l2vpn xconnect` — primary ACTIVE, backup STANDBY.
3. Test: fail primary PW; confirm switchover to backup; CE↔CE L2 reachability restored.

---

## Section 2: EVPN-VPWS on Garnet (BGP-signalled)

### Task 5: BGP l2vpn evpn
1. On PE3 + PE4: `router bgp 65200` → `address-family l2vpn evpn`; peer to RR PCE (13.13.13.13) or PE-PE.
2. Verify: `show bgp l2vpn evpn summary` — sessions Established.

### Task 6: EVPN-VPWS service PE3↔PE4
1. `l2vpn / xconnect group GARNET / p2p VPWS1` with EVPN service: `interface <ac>` + `neighbor evpn evi <N> target <local-ac-id> source <remote-ac-id>`.
2. Verify: `show l2vpn xconnect` — UP (EVPN type).
3. Verify: `show bgp l2vpn evpn` — EVPN Type-1 (AD per-EVI) routes exchanged.

### Task 7: Compare AToM vs EVPN-VPWS
1. Note signalling: AToM = targeted LDP (manual PW-id), EVPN-VPWS = BGP auto-discovery (EVI/AD routes).
2. Note redundancy model: AToM backup PW (manual) vs EVPN all-active/single-active via ESI (foundation for E13 dual-homing).

---

## Section 3: Snapshot
1. Take GNS3 snapshot: **"E05-l2vpn-atom-evpn"**.

---

## Verification Checklist
```
[ ] Emerald: ACs UP toward CE1/CE2
[ ] Emerald: AToM PW PE1↔PE2 UP via targeted LDP
[ ] Emerald: control word enabled both ends
[ ] Emerald: backup PW STANDBY; switchover verified on primary failure
[ ] Garnet: BGP l2vpn evpn sessions Established
[ ] Garnet: EVPN-VPWS PE3↔PE4 UP; Type-1 AD routes present
[ ] Documented AToM (tLDP) vs EVPN-VPWS (BGP-AD) comparison
```
