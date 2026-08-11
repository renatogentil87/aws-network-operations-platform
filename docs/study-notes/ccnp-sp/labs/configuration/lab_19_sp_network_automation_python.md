# Lab 19: SP Network Automation with Python — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2) + Python 3.14 on Mac
**Topology:** 20 routers — 4 PEs, 9 P routers, 7 CEs. Same topology as all labs.
**Prerequisite:** Labs 1-2 complete (OSPF + LDP + L3VPN running). Python 3 installed with `jinja2` and `pyyaml`.

**End Goal:** A fully automated SP operations toolkit where you can provision new VPN customers, monitor network health, trace label paths, detect faults, and roll back changes — all from Python scripts interacting with your live GNS3 routers via telnet. By the end, you never manually type `show` commands for routine operations again.

---

## Section 1: Build the Connection Library

### Task 1: Raw Telnet Client Function

1. Write a Python function `connect_and_run(host, port, commands, timeout=10)` using raw `socket` (not telnetlib — removed in Python 3.13+)
2. The function connects to localhost on the given port, waits 1 second for the prompt, sends each command with `\r\n`, waits for output, and returns the combined output as a string
3. Handle socket timeout gracefully — return partial output if timeout occurs, don't crash
4. Handle connection refused — return an error string, don't crash
5. Test against R2 (port 5000) with command `show ip interface brief`
6. Test against R8 (port 5006) with command `show mpls ldp neighbor`
7. Verify: both return valid IOS output containing expected interface/neighbor data
8. Save as `python/netops/lib/telnet_client.py`

### Task 2: Inventory Loader

1. Write a function `load_inventory(path)` that reads `python/netops/configurator/inventory.yaml`
2. Return a dictionary keyed by router name with port, loopback, role, and links
3. Write a helper function `get_routers_by_role(inventory, role)` that filters by role (PE, P, CE)
4. Verify: `get_routers_by_role(inv, 'PE')` returns `['R2', 'R8', 'R17', 'R18']`
5. Verify: `get_routers_by_role(inv, 'P')` returns the 9 P routers
6. Save as `python/netops/lib/inventory.py`

### Task 3: Batch Command Executor

1. Write a function `run_on_all(routers, command)` that takes a list of router dicts and a command string
2. Connects to each router sequentially, runs the command, collects output
3. Returns a dictionary: `{'R2': '<output>', 'R3': '<output>', ...}`
4. Add a `parallel=True` option that uses `concurrent.futures.ThreadPoolExecutor` to run connections simultaneously
5. Test: run `show clock` on all 13 P/PE routers — collect all outputs in under 30 seconds
6. Verify: output dictionary has 13 entries, all containing valid timestamps
7. Test parallel mode: same 13 routers complete in under 10 seconds

### Task 4: Output Parser — OSPF Neighbors

1. Write a function `parse_ospf_neighbors(output)` that takes raw `show ip ospf neighbor` output
2. Returns a list of dictionaries: `[{'neighbor_id': '3.3.3.3', 'state': 'FULL', 'interface': 'Gi1/0'}, ...]`
3. Handle the IOS output format: skip header lines, parse columns correctly
4. Handle edge cases: no neighbors (empty list), multiple neighbors, DR/BDR/DROTHER states
5. Test: run `show ip ospf neighbor` on R5, parse it — verify you get 4 neighbors all in FULL state
6. Verify: each parsed entry has `neighbor_id`, `state`, `dead_time`, `address`, `interface`

### Task 5: Output Parser — MPLS Forwarding Table

1. Write a function `parse_mpls_lfib(output, prefix=None)` that parses `show mpls forwarding-table` output
2. Returns a list of entries: `[{'local_label': '602', 'outgoing_label': '533', 'prefix': '8.8.8.8/32', 'interface': 'Fa0/0', 'next_hop': '172.16.65.2'}, ...]`
3. If `prefix` is given, filter to only entries matching that prefix
4. Handle "Pop Label" and "No Label" as special outgoing_label values
5. Test: parse R6's LFIB and extract the entry for 8.8.8.8/32
6. Verify: the parsed entry shows the correct outgoing label and interface toward R8

---

## Section 2: State Collection Scripts

### Task 6: OSPF Health Collector

1. Write `collectors/ospf_health.py` that connects to all P/PE routers and checks OSPF adjacencies
2. For each router: run `show ip ospf neighbor`, parse results
3. Output a formatted table to stdout:
   ```
   Router  Neighbors  All FULL?  Details
   R2      2          YES        
   R3      4          YES        
   R5      4          YES        
   R13     3          NO         R6 (Fa3/0) = INIT
   ```
4. Exit code 0 if all healthy, exit code 1 if any adjacency is not FULL
5. Verify: run on healthy topology → exit code 0, all YES
6. Shut an interface on one router → re-run → correctly shows missing neighbor and exit code 1
7. Bring interface back → run again → returns to healthy

### Task 7: LDP Session Collector

1. Write `collectors/ldp_health.py` that connects to all P/PE routers
2. Parse `show mpls ldp neighbor` — extract peer LDP ID, state, and uptime
3. Compare against OSPF neighbors: every OSPF neighbor should have a corresponding LDP session
4. Flag any mismatches:
   ```
   [OK]   R2: 2 OSPF neighbors, 2 LDP sessions — all matched
   [WARN] R5: 4 OSPF neighbors, 3 LDP sessions — MISSING LDP to 8.8.8.8
   ```
5. Flag LDP sessions with uptime < 60 seconds (recently flapped)
6. Verify: on healthy topology all show OK
7. Remove `mpls ip` from one interface → re-run → correctly flags the mismatch

### Task 8: LSP Path Tracer

1. Write `collectors/trace_lsp.py` that takes two arguments: source loopback and destination loopback
2. Usage: `python3 trace_lsp.py 2.2.2.2 8.8.8.8`
3. Starting from the source router:
   - Run `show mpls forwarding-table <destination>/32`
   - Extract the outgoing label and outgoing interface
   - Determine the next-hop router from the interface IP
   - Connect to the next-hop router and repeat
   - Stop when outgoing label is "Pop" (PHP) or you reach the destination
4. Output:
   ```
   LSP Trace: 2.2.2.2 → 8.8.8.8
     Hop 1: R2 — Push 602 → Gi2/0 (172.16.26.1)
     Hop 2: R6 — Swap 602→533 → Fa0/0 (172.16.65.1)
     Hop 3: R5 — Pop → Gi2/0 (172.16.58.1)
     Hop 4: R8 — Destination reached
   LSP valid: 3 label operations, 4 hops
   ```
5. Verify: trace from R2→R8 and R17→R2 — both show valid label paths
6. Verify: trace to a destination with no label (remove `mpls ip` somewhere) — reports "BROKEN: No label at hop X"

### Task 9: VPN Route Collector

1. Write `collectors/vpn_routes.py` that discovers all VRFs on all PEs and collects their routing tables
2. On each PE: run `show ip vrf` to discover VRF names dynamically
3. For each VRF: run `show ip route vrf <name>` and parse the routes
4. Output to `reports/vpn_routes.json`:
   ```json
   {
     "timestamp": "2026-08-05T15:00:00",
     "pe_routers": {
       "R2": {
         "Customer_A": {"routes": ["1.1.1.1/32", "9.9.9.9/32"], "count": 2},
         "Customer_B": {"routes": ["12.12.12.12/32", "11.11.11.11/32"], "count": 2}
       }
     }
   }
   ```
5. Also print a summary table to stdout:
   ```
   PE    VRF          Routes
   R2    Customer_A   4
   R2    Customer_B   3
   R8    Customer_A   4
   R17   Customer_D   3
   ```
6. Verify: run → JSON file created with correct route counts matching `show ip route vrf` on each PE

### Task 10: Configuration Backup Tool

1. Write `collectors/config_backup.py` that backs up all 20 routers
2. Connect to each router, run `show running-config`
3. Save to `backups/R<N>_<YYYYMMDD_HHMM>.cfg`
4. Strip the first line (Building configuration...) and last line (end) timestamps that change each time
5. Create `backups/manifest.json`:
   ```json
   {"backups": [{"router": "R2", "file": "R2_20260805_1500.cfg", "timestamp": "...", "size_lines": 142}]}
   ```
6. Add `--diff` flag: if a previous backup exists, show a unified diff of what changed since last backup
7. Verify: run twice — second run with `--diff` shows "No changes" for all routers
8. Make a config change on R2 → run with `--diff` → shows the exact change

---

## Section 3: Automated Provisioning

### Task 11: Jinja2 Template — New Customer VRF

1. Create `templates/vrf_customer.j2` — a Jinja2 template that generates full VRF provisioning config:
   ```
   ip vrf {{ vrf_name }}
    rd {{ rd }}
    route-target export {{ rt_export }}
    route-target import {{ rt_import }}
   !
   interface {{ ce_interface }}
    ip vrf forwarding {{ vrf_name }}
    ip address {{ ce_ip }} {{ ce_mask }}
    no shutdown
   !
   router bgp {{ bgp_asn }}
    address-family ipv4 vrf {{ vrf_name }}
     neighbor {{ ce_neighbor_ip }} remote-as {{ ce_as }}
     neighbor {{ ce_neighbor_ip }} activate
     neighbor {{ ce_neighbor_ip }} as-override
     redistribute connected
    exit-address-family
   ```
2. Write a Python function `render_vrf_config(template_path, variables)` that loads the template and renders it
3. Test with variables:
   ```yaml
   vrf_name: Customer_F
   rd: "64512:600"
   rt_export: "64512:600"
   rt_import: "64512:600"
   ce_interface: FastEthernet4/0
   ce_ip: 10.2.20.1
   ce_mask: 255.255.255.252
   bgp_asn: 64512
   ce_neighbor_ip: 10.2.20.2
   ce_as: 65099
   ```
4. Verify: rendered output is valid IOS config — no Jinja2 artifacts, no missing variables
5. Save the renderer as `provisioners/template_renderer.py`

### Task 12: Push Config to Router

1. Write `provisioners/push_config.py` that takes a router name and a config snippet (string or file)
2. Connects to the router, enters `configure terminal`, sends each line of config, then `end`
3. After pushing: runs a verification command (passed as argument) and checks for expected output
4. Returns PASS if verification succeeds, FAIL with details if not
5. Usage: `python3 push_config.py R2 --config-file customer_f.cfg --verify "show ip vrf Customer_F" --expect "Customer_F"`
6. Test: push a Loopback99 config to R2, verify with `show ip interface brief | include Loopback99`
7. Verify: Loopback99 appears on R2 after push
8. Clean up: push `no interface Loopback99` to remove it

### Task 13: End-to-End Customer Provisioning

1. Write `provisioners/provision_customer.py` that reads a YAML customer definition file:
   ```yaml
   customer_name: Customer_F
   rd: "64512:600"
   rt: "64512:600"
   sites:
     - pe: R2
       port: 5000
       ce_interface: FastEthernet4/0
       ce_ip: 10.2.20.1
       ce_mask: 255.255.255.252
       ce_as: 65099
       ce_neighbor: 10.2.20.2
     - pe: R17
       port: 5016
       ce_interface: FastEthernet4/0
       ce_ip: 10.17.20.1
       ce_mask: 255.255.255.252
       ce_as: 65099
       ce_neighbor: 10.17.20.2
   ```
2. For each site: render the Jinja2 template, push config to the PE
3. After all sites provisioned: verify VRF exists on each PE (`show ip vrf <name>`)
4. Verify vpnv4 routes are exchanged: check `show ip bgp vpnv4 vrf <name>` on each PE for routes from other sites
5. Output a summary:
   ```
   Provisioning Customer_F...
     R2:  VRF created ✓  BGP neighbor configured ✓  Routes received: 0 (CE not connected)
     R17: VRF created ✓  BGP neighbor configured ✓  Routes received: 0 (CE not connected)
   Result: PASS — VPN infrastructure ready (awaiting CE activation)
   ```
6. Add `--dry-run` flag that prints config without pushing
7. Verify: run with --dry-run → shows config, router unchanged. Run without → VRF appears on both PEs.

### Task 14: TE Tunnel Provisioner

1. Write `provisioners/provision_tunnel.py` that creates TE tunnels from YAML:
   ```yaml
   tunnel_id: 5
   headend: R2
   headend_port: 5000
   destination: 17.17.17.17
   bandwidth: 50000
   path_option: dynamic
   autoroute: true
   ```
2. Generate the tunnel interface config (mode, destination, bandwidth, path-option, autoroute, ip unnumbered)
3. Push to the headend router
4. Poll `show mpls traffic-eng tunnels tunnel<id>` every 5 seconds for up to 30 seconds
5. Report: UP (with path) or FAIL (with last error from the tunnel output)
6. Add `--explicit-path` option that accepts a list of hop addresses and creates the explicit-path + uses it
7. Verify: create Tunnel5 to R17 dynamically → comes UP. Create Tunnel6 with explicit path R6→R13→R17 → comes UP.

### Task 15: Customer Deprovisioning

1. Write `provisioners/deprovision_customer.py` that removes a customer VRF from all PEs
2. Reads the same YAML format as Task 13
3. Generates "undo" config: removes BGP VRF AF config, removes VRF from interface, removes VRF definition
4. Pushes to each PE in order (BGP first, then interface, then VRF — correct removal order)
5. Verifies: `show ip vrf <name>` returns empty after removal
6. Add `--dry-run` flag
7. Verify: provision Customer_F (Task 13) → deprovision it → VRF gone from all PEs. No impact on other customers.

---

## Section 4: Monitoring & Alerting

### Task 16: VPN End-to-End Validation

1. Write `monitors/validate_vpn.py` that reads a test definition YAML:
   ```yaml
   tests:
     - name: "Customer_A: R1→R9"
       source_router: R1
       source_port: 5009
       dest_ip: 9.9.9.9
       expected: reachable
     - name: "Isolation: R1→R12"
       source_router: R1
       source_port: 5009
       dest_ip: 12.12.12.12
       expected: unreachable
     - name: "Customer_B: R12→R11"
       source_router: R12
       source_port: 5011
       dest_ip: 11.11.11.11
       expected: reachable
   ```
2. For each test: connect to source router, run `ping <dest> repeat 3 timeout 2`
3. Parse success rate from output
4. Compare against expected (reachable = >0% success, unreachable = 0% success)
5. Output:
   ```
   [PASS] Customer_A: R1→R9 — 100% (expected: reachable)
   [PASS] Isolation: R1→R12 — 0% (expected: unreachable)
   [FAIL] Customer_B: R12→R11 — 0% (expected: reachable) ← INVESTIGATE
   Summary: 2/3 PASS, 1 FAIL
   ```
6. Exit code 0 if all pass, 1 if any fail
7. Verify: run on healthy topology → all PASS. Break Customer_B → detects the failure.

### Task 17: Full Health Report

1. Write `monitors/health_report.py` that combines OSPF, LDP, VPN, and TE checks into one report
2. Runs all four checks (reuse functions from Tasks 6, 7, 8, 16)
3. Generates `reports/health_<timestamp>.json`:
   ```json
   {
     "timestamp": "2026-08-05T15:00:00",
     "overall": "HEALTHY",
     "ospf": {"status": "HEALTHY", "routers_checked": 13, "issues": []},
     "ldp": {"status": "HEALTHY", "sessions": 26, "issues": []},
     "vpn": {"status": "HEALTHY", "tests_passed": 5, "tests_failed": 0},
     "te": {"status": "HEALTHY", "tunnels_up": 2, "tunnels_down": 0}
   }
   ```
4. Also prints human-readable summary to stdout
5. Overall status logic: HEALTHY (zero issues), DEGRADED (non-critical issues), CRITICAL (VPN or OSPF failures)
6. Verify: run on healthy network → HEALTHY. Break something → DEGRADED or CRITICAL with details.

### Task 18: Continuous Monitor (Loop Mode)

1. Add `--loop` flag to `health_report.py` that runs checks every 60 seconds continuously
2. Prints a one-line status each cycle: `[15:00:00] HEALTHY | OSPF:✓ LDP:✓ VPN:✓ TE:✓`
3. When status changes from HEALTHY to anything else: print full details
4. Log all state changes to `logs/monitor_<date>.log`
5. Press Ctrl+C to stop gracefully (print summary of the session)
6. Verify: start monitor, break something, watch it detect the failure within 60 seconds, fix it, watch it recover

---

## Section 5: Change Management

### Task 19: Pre/Post Change Validator

1. Write `change_mgmt/change_validator.py` with two modes: `--pre` and `--post`
2. `--pre` mode: captures current state (OSPF neighbors, LDP sessions, VPN route counts, TE tunnel states) → saves to `state/pre_change.json`
3. `--post` mode: captures state again → compares with pre_change.json → reports differences:
   ```
   === Change Impact Report ===
   OSPF:  No change
   LDP:   +1 session (R5↔R8 restored)
   VPN:   +2 routes in Customer_F on R2 (new VRF provisioned)
   TE:    Tunnel5 — NEW (UP, dynamic to 17.17.17.17)
   
   Assessment: Non-disruptive change. No losses detected.
   ```
4. If ANY session/route was LOST: flag as potentially disruptive
5. Verify: run --pre, provision a new VRF, run --post → correctly identifies the new routes. Run --pre, shut a link, run --post → identifies the lost adjacency.

### Task 20: Config Diff and Rollback

1. Write `change_mgmt/config_diff.py` that takes two backup files and shows meaningful differences:
   ```
   python3 config_diff.py backups/R2_before.cfg backups/R2_after.cfg
   ```
   Output:
   ```
   === R2 Changes ===
   [ADDED]   ip vrf Customer_F
   [ADDED]     rd 64512:600
   [ADDED]     route-target export 64512:600
   [ADDED]   interface FastEthernet4/0 → ip vrf forwarding Customer_F
   [REMOVED] interface FastEthernet4/0 → shutdown
   ```
2. Ignore non-meaningful changes (timestamps, `ntp clock-period`, `! Last configuration change`)
3. Write `change_mgmt/rollback.py` that generates "undo" commands from a diff:
   - ADDED lines → generate `no <line>` commands
   - REMOVED lines → generate the original line (re-add)
4. Add `--dry-run` (show undo commands) and `--apply` (push to router) modes
5. Verify: backup R2, add a loopback, backup again, run diff → shows the change. Run rollback --apply → loopback removed. Verify with `show ip interface brief`.

---

## CCIE+ Challenges

### Challenge 1: Rolling Deployment with Health Gates

1. Write `change_mgmt/rolling_deploy.py` that pushes config to multiple routers one at a time
2. Input: list of target routers + config template + health check definition
3. After each router: run health check (OSPF neighbors OK, VPN still works)
4. If health passes → move to next router
5. If health fails → STOP immediately, report which router broke, suggest rollback
6. Output:
   ```
   [1/4] R3:  Config pushed ✓  Health gate: PASS  → continuing
   [2/4] R4:  Config pushed ✓  Health gate: PASS  → continuing
   [3/4] R5:  Config pushed ✓  Health gate: FAIL  → STOPPED
     Reason: OSPF neighbor 8.8.8.8 lost on R5 after config push
     Action: Review R5 config. Consider rollback.
   ```
7. Verify: push a safe change (add a description to interfaces) across 4 routers → all pass. Push a breaking change → stops at first failure.

### Challenge 2: Topology Auto-Discovery

1. Write `advanced/discover_topology.py` that builds a network graph from live router data
2. Connect to all routers, parse `show ip ospf neighbor` (or `show cdp neighbors detail`)
3. Build an adjacency graph and output `reports/topology.json`:
   ```json
   {
     "nodes": [{"name": "R2", "role": "PE", "loopback": "2.2.2.2"}, ...],
     "edges": [{"from": "R2", "to": "R3", "from_intf": "Gi1/0", "to_intf": "Gi1/0", "type": "GigE"}, ...]
   }
   ```
4. Detect single points of failure: nodes whose removal disconnects the graph
5. Report: `SPOFs detected: R6 (connects north core to south core)`
6. Verify: output matches your physical topology. SPOF analysis identifies the R6↔R13 bridge link.

### Challenge 3: Self-Healing Daemon

1. Write `advanced/self_heal.py` that runs as a continuous daemon (60-second loop)
2. Monitors LDP and VPN health
3. Auto-remediation rules:
   - LDP session DOWN but OSPF UP → `clear mpls ldp neighbor <ip>` (soft reset)
   - VPN route missing but PE-CE BGP Established → `clear ip bgp <neighbor> soft in` (refresh)
   - Wait 15 seconds after each action and re-check
   - If still broken after 2 attempts → log "ESCALATE: manual intervention needed"
4. NEVER make destructive changes (no shutdown, no config removal — only soft clears)
5. All actions logged to `logs/self_heal_<date>.log` with timestamps
6. Verify: break an LDP session (clear it manually), start self_heal → it detects and recovers. Check the log file.

### Challenge 4: Scheduled Maintenance Window

1. Write `change_mgmt/maintenance_window.py` that executes a change with safety net:
   - Backs up current config
   - Sets `reload in 5` on the target router (auto-reboot in 5 minutes if something goes wrong)
   - Pushes the change
   - Runs health check
   - If healthy: cancels reload (`reload cancel`), reports success
   - If NOT healthy within 4 minutes: lets router reload (automatic rollback to startup-config)
2. Usage: `python3 maintenance_window.py R2 --config change.cfg --health-check "ping 8.8.8.8 repeat 3"`
3. Verify: push a good change → reload cancelled, change persisted. Push a bad change (wrong IP on an interface) → router reloads, recovers.

---

## Final Validation

By the end of this lab, your toolkit has:

- [ ] Reusable telnet client library (raw socket, no external dependencies)
- [ ] Inventory-driven batch execution (sequential and parallel)
- [ ] OSPF, LDP, LFIB, and VPN output parsers
- [ ] LSP path tracer (follows labels hop-by-hop)
- [ ] VPN route collector outputting structured JSON
- [ ] Automated config backup with diff capability
- [ ] Jinja2 templates for VRF and TE tunnel provisioning
- [ ] Push-and-verify provisioning scripts with --dry-run mode
- [ ] End-to-end customer provisioning and deprovisioning
- [ ] VPN connectivity validation (reachable/unreachable tests)
- [ ] Full health report combining all monitors
- [ ] Continuous monitoring with state-change detection
- [ ] Pre/post change comparison showing impact
- [ ] Config diff and rollback engine
- [ ] (CCIE+) Rolling deployment with health gates
- [ ] (CCIE+) Topology auto-discovery with SPOF detection
- [ ] (CCIE+) Self-healing daemon with auto-remediation
- [ ] (CCIE+) Maintenance window automation with reload safety net
