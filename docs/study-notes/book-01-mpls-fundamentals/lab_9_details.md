# Lab 9: Python Automation — Workbook

**Platform:** GNS3 Local (Cisco 7200) + Python/Netmiko
**Prerequisite:** push_config.py working, inventory.yaml populated

---

## Task 1: New Customer Provisioning (Template)

1. Create a Jinja2 template called `new_customer_vrf.j2` that configures:
   - VRF creation (name, RD, RT)
   - Loopback in VRF
   - PE-CE interface in VRF with IP
   - BGP vpnv4 activation (if not already done)
   - BGP VRF address-family with CE neighbor
2. Add a new customer "Customer_F" to the inventory for R17
3. Run `push_config.py --router R17 --template new_customer_vrf.j2 --dry-run`
4. Review the output — does it look correct?
5. Push it live (without --dry-run)
6. Verify: `show ip vrf` on R17 shows the new VRF

---

## Task 2: Bulk P Router Configuration

1. Add `--role` argument to push_config.py (filter routers by role)
2. Run: `push_config.py --role P --template mpls_base.j2 --dry-run`
3. Verify: only P routers are listed (not PEs or CEs)
4. Push to all P routers at once
5. Verify: all P routers have consistent OSPF + MPLS + LDP configuration

---

## Task 3: State Collector — OSPF Neighbors

1. Create `python/netops/collectors/ospf_collector.py`
2. Connect to each P and PE router
3. Run `show ip ospf neighbor` on each
4. Parse the output — extract: Neighbor ID, State, Interface
5. Print a summary table: which router has which OSPF neighbors, and are they all Full?
6. Test: shut one interface — re-run the collector — verify it shows the missing adjacency

---

## Task 4: State Collector — LDP Neighbors

1. Create `python/netops/collectors/ldp_collector.py`
2. Connect to each P and PE router
3. Run `show mpls ldp neighbor` on each
4. Parse: Peer LDP Ident, State, Up time
5. Print summary: all LDP peers across the network
6. Test: shut MPLS on one link — re-run — verify missing LDP neighbor detected

---

## Task 5: State Collector — BGP VPNv4 Summary

1. Create `python/netops/collectors/bgp_collector.py`
2. Connect to each PE router only (filter by role PE in inventory)
3. Run `show ip bgp vpnv4 all summary`
4. Parse: Neighbor, State, Prefixes Received
5. Print summary: which PE peers with whom, how many prefixes exchanged
6. Alert if any PE has 0 prefixes received (broken vpnv4 session)

---

## Task 6: State Collector — TE Tunnel Status

1. Create `python/netops/collectors/te_collector.py`
2. Connect to PEs that have TE tunnels (R2, R8)
3. Run `show mpls traffic-eng tunnels brief`
4. Parse: Tunnel name, Destination, State, Path option active
5. Print summary: all tunnels, their status, which path they're using
6. Alert if any tunnel is down or using backup path

---

## Task 7: Validator — OSPF Full Mesh

1. Create `python/netops/validators/ospf_validator.py`
2. Define expected OSPF neighbors per router (in inventory or separate file)
3. Run the OSPF collector
4. Compare actual vs expected
5. Report: PASS if all expected neighbors are Full, FAIL if any missing
6. Test: shut a link — run validator — should report FAIL

---

## Task 8: Validator — Full Health Check

1. Create `python/netops/validators/health_check.py`
2. Run ALL collectors (OSPF, LDP, BGP, TE)
3. Check:
   - All OSPF neighbors Full?
   - All LDP neighbors Up?
   - All BGP vpnv4 sessions Established with > 0 prefixes?
   - All TE tunnels Up on primary path?
4. Print summary report:
   ```
   OSPF:  PASS (28/28 adjacencies Full)
   LDP:   PASS (24/24 neighbors Up)
   BGP:   PASS (4/4 vpnv4 sessions, all receiving prefixes)
   TE:    FAIL (Tunnel0 on backup path)
   ```
5. Test: break something — verify the report catches it

---

## Task 9: Config Backup

1. Create `python/netops/collectors/config_backup.py`
2. Connect to all 20 routers
3. Run `show running-config` on each
4. Save to `configs/R1.cfg`, `configs/R2.cfg`, etc.
5. Run it — verify all 20 configs saved
6. Make a change on one router — run backup again
7. Use `git diff` to see what changed — proves version control of configs

---

## Task 10: Automated Verification After Config Push

1. Modify push_config.py to run verification after pushing config:
   - After push: wait 30 seconds for protocols to converge
   - Run `show ip ospf neighbor` — verify new adjacency formed
   - Run `show mpls ldp neighbor` — verify LDP session up
   - Run `show ip bgp vpnv4 all summary` — verify BGP session (if PE)
2. Print verification results immediately after push
3. Test: push config to a new router — observe verification output
4. If verification fails: print warning "Config pushed but verification FAILED"

---

## Validation Checklist

- [ ] New customer provisioned via template + push (no manual CLI)
- [ ] Bulk configuration to all routers of same role
- [ ] OSPF collector reports all adjacencies
- [ ] LDP collector reports all neighbors with uptime
- [ ] BGP collector reports vpnv4 session health
- [ ] TE collector reports tunnel status and active path
- [ ] Validator detects missing OSPF adjacency
- [ ] Health check runs all validators and reports summary
- [ ] Config backup saves all 20 router configs to files
- [ ] Post-push verification confirms protocols converge
