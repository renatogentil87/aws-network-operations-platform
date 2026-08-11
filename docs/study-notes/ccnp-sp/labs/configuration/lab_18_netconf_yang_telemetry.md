# Lab 18: Model-Driven Programmability — NETCONF, YANG & Telemetry — Workbook

**Platform:** EVE-NG on AWS c5.metal
**Images Required:** IOS-XRv 9000 (7.x+), CSR1000v (IOS-XE 17.x+)
**Additional Tools:** Python 3.x with ncclient, pyang; gRPC tools (grpcurl or custom Python client)
**Topology:** Reuse Lab 16 topology (SR core) — same 10 routers

**⚠️ EVE-NG REQUIRED:** This lab requires IOS-XR/XE for NETCONF/YANG support. Cisco 7200 IOS 15.2 has minimal or no YANG model support. Deploy on your c5.metal EVE-NG instance.

**End Goal:** Replace CLI-based operations with model-driven APIs. By the end, you can retrieve operational data, push configuration changes, and stream real-time telemetry — all programmatically via NETCONF/YANG and gRPC. This is the SPCOR "Infrastructure Services — Automation" requirement.

---

## EVE-NG Topology

Reuse the Lab 16 Segment Routing topology (10 routers, IS-IS core). All routers must have:
- Management interfaces reachable from your Python workstation
- NETCONF enabled (port 830)
- gRPC enabled (port 57400 on IOS-XR)

---

## Section 1: YANG Models — Understanding the Data Structures

### Task 1: Explore YANG Models

1. On your workstation: install `pyang` — `pip install pyang`
2. Download IOS-XR YANG models from GitHub: `github.com/YangModels/yang`
3. Explore the interface model:
   - `pyang -f tree Cisco-IOS-XR-ifmgr-cfg.yang` — view tree structure
4. Explore the BGP model:
   - `pyang -f tree Cisco-IOS-XR-ipv4-bgp-cfg.yang`
5. Understand the hierarchy: module → container → list → leaf
6. Key concept: YANG defines the STRUCTURE. NETCONF is the PROTOCOL to read/write that structure.
7. Compare: CLI is unstructured text. YANG/NETCONF is structured XML — parseable, automatable.

### Task 2: Identify Relevant SP Models

1. List key YANG models for SP operations:
   - `openconfig-interfaces` — interface configuration and state
   - `openconfig-network-instance` — VRF, routing instances
   - `openconfig-bgp` — BGP configuration
   - `Cisco-IOS-XR-mpls-ldp-cfg` — LDP configuration
   - `Cisco-IOS-XR-segment-routing-ms-cfg` — Segment Routing
   - `Cisco-IOS-XR-infra-statsd-oper` — interface statistics (operational)
2. Distinguish: `-cfg` models = configuration (read/write). `-oper` models = operational state (read-only)
3. `pyang -f tree <model>.yang | head -50` — examine the first 50 lines of each
4. **SPCOR expects:** understanding of YANG model types (OpenConfig vs native), cfg vs oper, and basic tree navigation

---

## Section 2: NETCONF — Configuration and Operational Data

### Task 3: Enable NETCONF on Routers

1. On all IOS-XR routers:
   ```
   ssh server v2
   ssh server netconf vrf default
   netconf-yang agent ssh
   ```
2. On CSR1000v (IOS-XE):
   ```
   netconf-yang
   ```
3. Verify: from your workstation, test SSH to port 830:
   - `ssh -p 830 admin@<router-mgmt-ip> -s netconf`
   - You should receive the `<hello>` message with capabilities list
4. Verify: capabilities include YANG models you need (BGP, interfaces, etc.)

### Task 4: Retrieve Configuration via NETCONF (get-config)

1. Write a Python script using `ncclient`:
   ```python
   from ncclient import manager

   with manager.connect(
       host='10.0.0.1', port=830,
       username='admin', password='admin',
       hostkey_verify=False
   ) as m:
       # Get all interfaces configuration
       filter = '''
       <interfaces xmlns="http://openconfig.net/yang/interfaces"/>
       '''
       result = m.get_config(source='running', filter=('subtree', filter))
       print(result)
   ```
2. Run against PE1 — retrieve all interface configuration as XML
3. Parse the output: identify interface names, IP addresses, descriptions
4. Modify the filter to get only BGP configuration:
   ```xml
   <bgp xmlns="http://openconfig.net/yang/bgp"/>
   ```
5. Retrieve BGP config from PE1 — verify it matches what you configured in Lab 16
6. **Key advantage:** structured XML output. No screen-scraping. No regex parsing.

### Task 5: Retrieve Operational Data (get)

1. Use `get` (not `get-config`) to retrieve runtime state:
   ```python
   filter = '''
   <interfaces xmlns="http://openconfig.net/yang/interfaces">
     <interface>
       <state/>
     </interface>
   </interfaces>
   '''
   result = m.get(filter=('subtree', filter))
   ```
2. Parse: interface counters (packets in/out, errors, drops)
3. Retrieve BGP neighbor state:
   ```xml
   <bgp xmlns="http://openconfig.net/yang/bgp">
     <neighbors><neighbor><state/></neighbor></neighbors>
   </bgp>
   ```
4. Verify: operational data shows session state (Established), prefixes received, uptime
5. Compare: `show ip bgp summary` (CLI) vs NETCONF get (structured XML) — same data, different format

### Task 6: Push Configuration via NETCONF (edit-config)

1. Create a new loopback interface on PE1 via NETCONF:
   ```python
   config = '''
   <config>
     <interfaces xmlns="http://openconfig.net/yang/interfaces">
       <interface>
         <name>Loopback100</name>
         <config>
           <name>Loopback100</name>
           <type xmlns:idx="urn:ietf:params:xml:ns:yang:iana-if-type">idx:softwareLoopback</type>
           <enabled>true</enabled>
         </config>
         <subinterfaces>
           <subinterface>
             <index>0</index>
             <ipv4 xmlns="http://openconfig.net/yang/interfaces/ip">
               <addresses>
                 <address>
                   <ip>10.99.99.1</ip>
                   <config>
                     <ip>10.99.99.1</ip>
                     <prefix-length>32</prefix-length>
                   </config>
                 </address>
               </addresses>
             </ipv4>
           </subinterface>
         </subinterfaces>
       </interface>
     </interfaces>
   </config>
   '''
   m.edit_config(target='candidate', config=config)
   m.commit()
   ```
2. Verify: SSH to PE1, `show interface Loopback100` — interface exists
3. Delete the loopback via NETCONF (use `operation="delete"` attribute)
4. Verify: loopback removed
5. **This is how automation tools (NSO, Ansible with NETCONF) configure routers** — no CLI templates

---

## Section 3: NETCONF for SP Operations

### Task 7: Configure a VRF via NETCONF

1. Push a complete L3VPN VRF configuration to PE1:
   - VRF name, RD, RT import/export
   - Interface assignment to VRF
   - BGP VRF neighbor
2. Use the appropriate YANG model (Cisco-native or OpenConfig network-instance)
3. Verify: `show vrf` on PE1 — new VRF created via API
4. Verify: `show bgp vrf <name> summary` — BGP session configures via API
5. **SP automation:** onboard a new customer by pushing YANG-modelled config (minutes vs hours of CLI)

### Task 8: Configuration Replace (Full Declarative)

1. Current state: PE1 has some configuration
2. Build a COMPLETE desired-state XML document for PE1's interfaces
3. Use `edit-config` with `default-operation="replace"`:
   - This REPLACES the entire interfaces container with your desired state
4. Verify: configuration now matches exactly what you sent — nothing extra, nothing missing
5. **Declarative model:** you define WHAT the config should be, not HOW to get there (no "no" commands)
6. Compare: CLI requires calculating the diff manually. NETCONF replace is idempotent.

### Task 9: NETCONF Transactions (Candidate vs Running)

1. On IOS-XR: NETCONF uses **candidate** datastore:
   - `edit-config(target='candidate')` — stages changes
   - `commit()` — applies atomically
   - `discard-changes()` — rolls back staged changes
2. Test: push invalid config to candidate → commit → observe error
3. Discard and fix — candidate resets to current running
4. Test: push valid config → commit → verify applied
5. **Transaction safety:** either ALL changes apply or NONE do (no partial config like CLI)
6. Compare with CLI: `configure terminal` has no atomic commit — partial failures leave broken state

---

## Section 4: Model-Driven Telemetry (gRPC/gNMI)

### Task 10: Enable gRPC Telemetry

1. On IOS-XR routers:
   ```
   grpc
    port 57400
    no-tls
   ```
2. Verify: port 57400 is listening — `show grpc status`
3. From workstation: test connectivity with `grpcurl`:
   ```
   grpcurl -plaintext <router-ip>:57400 list
   ```

### Task 11: Dial-Out Telemetry Subscription

1. On PE1: configure a telemetry subscription that pushes data to your collector:
   ```
   telemetry model-driven
    sensor-group INTERFACES
     sensor-path Cisco-IOS-XR-infra-statsd-oper:infra-statistics/interfaces/interface/latest/generic-counters
    subscription INTF-COUNTERS
     sensor-group-id INTERFACES sample-interval 10000
     destination-id MY-COLLECTOR
    destination-group MY-COLLECTOR
     address-family ipv4 <collector-ip> port 5432
      encoding self-describing-gpb
      protocol grpc no-tls
   ```
2. On your workstation: run a simple telemetry receiver (Python gRPC server or `pipeline` tool)
3. Verify: data streams arrive every 10 seconds with interface counters
4. **Compare with SNMP polling:** SNMP = pull every 5 minutes. Telemetry = push every 10 seconds. 30x more granular.

### Task 12: Dial-In Telemetry (gNMI Get/Subscribe)

1. From workstation: use gNMI to subscribe to real-time BGP state:
   ```python
   # Using python grpc/gnmi library
   subscribe_request = {
       'subscription': [{
           'path': '/bgp/neighbors/neighbor/state',
           'mode': 'SAMPLE',
           'sample_interval': 5000000000  # 5 seconds in nanoseconds
       }]
   }
   ```
2. Observe: BGP neighbor state streamed to your client every 5 seconds
3. Kill a BGP session — observe the state change in real-time telemetry (immediate notification)
4. Bring session back — observe "Established" in the stream
5. **Use case:** real-time dashboards, automated remediation triggered by state changes

---

## Section 5: Automation Workflows

### Task 13: Network State Validation via NETCONF

1. Write a Python script that:
   - Connects to ALL routers via NETCONF
   - Retrieves BGP neighbor state from each
   - Validates: all expected sessions are Established
   - Reports: PASS/FAIL per router
2. Run against your topology — verify all sessions UP
3. Kill one BGP session — re-run — script reports FAIL for that router
4. **Compare with Lab 9 (Netmiko):** Lab 9 parses CLI text with regex. This uses structured YANG data — no parsing errors, no regex maintenance.

### Task 14: Automated VRF Provisioning via NETCONF

1. Write a script that:
   - Takes customer name, RD, RT, PE list as input
   - Generates YANG XML configuration for VRF on each PE
   - Pushes via NETCONF edit-config + commit
   - Validates: VRF appears in operational state (get)
   - Reports: SUCCESS or FAILURE per PE
2. Provision a new customer across PE1, PE3, PE-WAN1 in one script execution
3. Verify: customer VPN operational end-to-end (configured entirely via API)
4. **SP scale:** with 100 PEs, this script provisions a customer in seconds. CLI would take hours.

### Task 15: Configuration Compliance Checking

1. Define a "golden config" for each router role (PE, P) as YANG XML templates
2. Write a script that:
   - Retrieves running config via NETCONF get-config
   - Compares against golden template (diff the XML trees)
   - Reports: deviations from standard (missing IS-IS config, wrong MTU, etc.)
3. Run against all routers — identify any configuration drift
4. Optional: auto-remediate by pushing the missing config via edit-config
5. **SP operations:** continuous compliance monitoring — detect unauthorized changes immediately

---

## CCIE+ Challenges

### Challenge 1: Zero-Touch Provisioning (ZTP) Concept

1. Design a ZTP workflow for a new P router joining the network:
   - Router boots with no config
   - DHCP provides management IP + script URL
   - Script runs: connects to router via NETCONF, pushes base config (IS-IS, SR, telemetry)
   - Router joins the SP core automatically
2. Document the workflow (may not be fully testable in EVE-NG without DHCP/PXE)
3. **SP scale:** deploy 100 new routers without touching CLI on any of them

### Challenge 2: Event-Driven Automation

1. Telemetry streams interface counters every 10 seconds
2. Write a script that:
   - Monitors interface utilization via telemetry
   - When utilization > 80%: triggers SR-TE policy creation (via NETCONF) to shift traffic
   - When utilization drops < 50%: removes the SR-TE policy
3. This is closed-loop automation — observe, decide, act — all programmatically
4. **Modern SP architecture:** intent-based networking + telemetry-driven control

### Challenge 3: RESTCONF as Alternative to NETCONF

1. On IOS-XE (CSR1000v): enable RESTCONF:
   ```
   restconf
   ip http secure-server
   ```
2. Use curl/Postman to GET interface data:
   ```
   curl -k https://<router>/restconf/data/openconfig-interfaces:interfaces
   ```
3. Use PUT/PATCH to modify configuration via REST API
4. Compare: NETCONF = XML + SSH + RPC. RESTCONF = JSON/XML + HTTPS + REST verbs.
5. **When to use which:** NETCONF for heavy config transactions (atomic commit). RESTCONF for lightweight queries and simple changes.

---

## Final Validation

By the end of this lab, your network has:

- [ ] YANG model structure understood (pyang tree exploration)
- [ ] NETCONF enabled on all routers (port 830 accessible)
- [ ] get-config retrieving structured configuration (interfaces, BGP, VRF)
- [ ] get retrieving operational state (counters, BGP session state)
- [ ] edit-config pushing configuration changes (create/modify/delete)
- [ ] Candidate datastore + commit for atomic transactions (IOS-XR)
- [ ] VRF provisioned entirely via NETCONF (no CLI)
- [ ] Configuration replace (declarative, idempotent)
- [ ] gRPC telemetry streaming interface counters in real-time
- [ ] Dial-out subscription pushing data to collector every 10 seconds
- [ ] Dial-in (gNMI) subscription for BGP state monitoring
- [ ] Python script validating network state via NETCONF
- [ ] Automated multi-PE VRF provisioning script
- [ ] Configuration compliance checking against golden templates
- [ ] (CCIE+) ZTP workflow designed for new router onboarding
- [ ] (CCIE+) Event-driven automation: telemetry → decision → config push
- [ ] (CCIE+) RESTCONF as alternative API understood
