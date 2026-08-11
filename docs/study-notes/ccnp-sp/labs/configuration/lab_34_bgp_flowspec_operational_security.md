# Lab 34: BGP Flowspec & Operational Security — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 26 routers — Topology E (multi-ASN from Lab 32)
**Prerequisite:** Labs 14, 32, 33 complete (infrastructure security basics, peering sessions active, RRs working)

**End Goal:** Deploy BGP-based traffic filtering and DDoS mitigation at SP scale. Configure BGP Flowspec (RFC 5575) to inject firewall-like rules into the forwarding plane via BGP, implement customer-triggered and auto-triggered Remote Triggered Blackholing (RTBH), deploy source-based RTBH, configure S/RTBH with uRPF loose mode, and build an operational DDoS response workflow. By the end, you understand how SPs mitigate volumetric attacks without scrubbing centers — the "first 30 seconds" response that every SP NOC must master.

**⚠️ Platform Note:** BGP Flowspec requires IOS-XR or IOS-XE 3.x+. Cisco 7200 IOS 15.2 has LIMITED Flowspec support (may only support receive, not install to hardware). This lab documents full IOS-XR syntax for reference, uses RTBH (fully supported on 7200) for hands-on practice, and covers Flowspec concepts thoroughly for exam readiness.

---

## Section 1: Remote Triggered Blackholing (RTBH) — Destination-Based

### Task 1: RTBH Architecture

1. **Concept:** when under DDoS attack, null-route the victim IP at the network edge — traffic is dropped before consuming backbone bandwidth.

2. **Components:**
   - **Trigger router:** injects /32 blackhole route with community
   - **Edge routers (ASBRs):** match community, set next-hop to Null0
   - **Static route to Null0 on a specific next-hop (e.g., 192.0.2.1):** all blackholed traffic goes here

3. **Flow:**
   ```
   Attack target: 192.0.2.5/32
   
   Trigger (R3) → iBGP → R10/R11/R12 (ASBRs) → match community 64512:666
                                                 → set next-hop 192.0.2.1
                                                 → 192.0.2.1 → Null0
                                                 → Packet dropped!
   
   Also: send to transit providers with THEIR blackhole community
         → Transit drops traffic at THEIR edge (upstream blackhole)
   ```

### Task 2: Configure RTBH Infrastructure

1. On ALL edge routers (R10, R11, R12) — create the blackhole next-hop:
   ```
   ip route 192.0.2.1 255.255.255.255 Null0
   ! This is the "blackhole next-hop" — any traffic with this NH gets dropped
   ```

2. On all edge routers — configure the policy to match blackhole community:
   ```
   ip community-list standard BLACKHOLE permit 64512:666
   
   route-map BLACKHOLE-IN permit 10
    match community BLACKHOLE
    set ip next-hop 192.0.2.1
    set local-preference 500
    ! High local-pref ensures blackhole wins over legitimate routes
   route-map BLACKHOLE-IN permit 20
    ! Pass everything else unchanged
   
   router bgp 64512
    address-family ipv4 unicast
     neighbor 3.3.3.3 route-map BLACKHOLE-IN in
     neighbor 7.7.7.7 route-map BLACKHOLE-IN in
    exit-address-family
   ```

3. On the trigger router (R3, acting as RR and control point):
   ```
   ! Static route for the blackhole target:
   ip route 192.0.2.5 255.255.255.255 Null0 tag 666
   
   router bgp 64512
    address-family ipv4 unicast
     network 192.0.2.5 mask 255.255.255.255 route-map BLACKHOLE-TAG
    exit-address-family
   
   route-map BLACKHOLE-TAG permit 10
    set community 64512:666
    set origin igp
   ```

### Task 3: Test Destination-Based RTBH

1. Before blackhole — verify 192.0.2.5 is reachable:
   ```
   ! On R21 (external, simulating attacker):
   ping 192.0.2.5 source 100.64.1.1
   ! Should succeed (traffic enters your network via R10)
   ```

2. Activate blackhole:
   ```
   ! On R3 (trigger router):
   ip route 192.0.2.5 255.255.255.255 Null0 tag 666
   ! Ensure the network statement is active in BGP
   ```

3. Verify blackhole propagation:
   ```
   ! On R10:
   show ip bgp 192.0.2.5/32
   ! Should show: community 64512:666, next-hop 192.0.2.1
   
   show ip route 192.0.2.5
   ! Should point to Null0
   
   ! Verify drop:
   ! On R21: ping 192.0.2.5
   ! Should FAIL — traffic blackholed at R10
   ```

4. Remove blackhole:
   ```
   ! On R3:
   no ip route 192.0.2.5 255.255.255.255 Null0 tag 666
   ```

### Task 4: Upstream/Transit RTBH (Push Blackhole to Provider)

1. Advertise the blackhole to transit providers using THEIR community:
   ```
   ! On R10 — modify TRANSIT-OUT to pass blackhole routes with provider community:
   route-map TRANSIT-OUT-BLACKHOLE permit 5
    match community BLACKHOLE
    set community 174:666 additive
    ! 174:666 = Cogent's blackhole community (real-world: check provider documentation)
   route-map TRANSIT-OUT-BLACKHOLE permit 10
    match ip address prefix-list OUR-SPACE
   route-map TRANSIT-OUT-BLACKHOLE deny 999
   
   ! Apply:
   router bgp 64512
    address-family ipv4 unicast
     neighbor 198.51.100.2 route-map TRANSIT-OUT-BLACKHOLE out
    exit-address-family
   ```

2. On R21 (simulating Cogent's blackhole behavior):
   ```
   ip community-list standard BH permit 174:666
   
   route-map CUSTOMER-IN permit 10
    match community BH
    set ip next-hop 198.51.100.99
    set local-preference 1000
   route-map CUSTOMER-IN permit 20
   
   ip route 198.51.100.99 255.255.255.255 Null0
   
   router bgp 174
    address-family ipv4 unicast
     neighbor 198.51.100.1 route-map CUSTOMER-IN in
    exit-address-family
   ```

3. **Result:** attack traffic is dropped at Cogent's edge — never reaches your network!

---

## Section 2: Source-Based RTBH (S/RTBH)

### Task 5: Understand Source-Based Blackholing

1. **Problem with destination RTBH:** you blackhole the VICTIM. Legitimate traffic to 192.0.2.5 is also dropped. The attacker wins — they achieved denial of service.

2. **Source-based RTBH (S/RTBH):** instead of blackholing the destination, blackhole traffic FROM the attacker's source IP. Legitimate traffic to the victim continues flowing.

3. **Mechanism:** use uRPF (Unicast Reverse Path Forwarding) in loose mode to achieve source-based filtering:
   - Inject a /32 route for the attacker's SOURCE IP pointing to Null0
   - Configure uRPF loose-mode on ingress interfaces
   - uRPF checks: "is there a route to the SOURCE IP?" → route points to Null0 → DROP
   - Legitimate sources have real routes → uRPF passes them

### Task 6: Configure S/RTBH

1. On ALL ingress interfaces (R10, R11, R12 — transit-facing):
   ```
   interface FastEthernet0/0
    ip verify unicast source reachable-via any allow-default
    ! "any" = loose mode (just check route exists, not interface-specific)
   ```

2. Create a separate community for source-based blackhole:
   ```
   ip community-list standard S-BLACKHOLE permit 64512:667
   ```

3. On edge routers — match S-RTBH community:
   ```
   route-map BLACKHOLE-IN permit 5
    match community S-BLACKHOLE
    set ip next-hop 192.0.2.1
    set local-preference 500
   route-map BLACKHOLE-IN permit 10
    match community BLACKHOLE
    set ip next-hop 192.0.2.1
    set local-preference 500
   route-map BLACKHOLE-IN permit 20
   ```

4. On trigger router (R3) — blackhole the attacker's source:
   ```
   ! Attacker source: 203.0.113.66
   ip route 203.0.113.66 255.255.255.255 Null0
   
   router bgp 64512
    address-family ipv4 unicast
     network 203.0.113.66 mask 255.255.255.255 route-map S-RTBH-TAG
    exit-address-family
   
   route-map S-RTBH-TAG permit 10
    set community 64512:667
   ```

### Task 7: Verify S/RTBH

1. Check route installation:
   ```
   ! On R10:
   show ip route 203.0.113.66
   ! Should point to Null0 (via BGP with community 64512:667)
   ```

2. Test:
   ```
   ! On R21 (simulate attacker with source 203.0.113.66):
   ping 192.0.2.5 source 203.0.113.66
   ! Should FAIL — uRPF check fails because source route → Null0
   
   ! On R21 (legitimate source 198.51.100.2):
   ping 192.0.2.5 source 198.51.100.2
   ! Should SUCCEED — uRPF check passes (real route to 198.51.100.0/30 exists)
   ```

3. **Key advantage:** victim (192.0.2.5) remains reachable for legitimate traffic!

---

## Section 3: BGP Flowspec (RFC 5575)

### Task 8: Understand Flowspec Concepts

1. **What Flowspec does:** distributes traffic filtering rules (like ACL entries) via BGP. Instead of logging into every router to add an ACL, you inject one BGP Flowspec route — ALL routers install the filter automatically.

2. **Flowspec NLRI components (match criteria):**
   | Type | Matches | Example |
   |---|---|---|
   | Destination prefix | Destination IP | 192.0.2.5/32 |
   | Source prefix | Source IP | 203.0.113.0/24 |
   | IP protocol | TCP/UDP/ICMP | protocol 17 (UDP) |
   | Port | Source or dest port | port 53 |
   | Destination port | Dest port specifically | dest-port 80 |
   | Source port | Source port specifically | source-port >1024 |
   | ICMP type/code | ICMP specifics | icmp-type 8 |
   | TCP flags | SYN, ACK, etc. | tcp-flags syn |
   | Packet length | Packet size | length 0-64 |
   | Fragment | Fragment flags | fragment is-fragment |

3. **Flowspec actions (extended communities):**
   | Action | Effect |
   |---|---|
   | Traffic-rate 0 | Drop (rate-limit to 0 bps) |
   | Traffic-rate X | Rate-limit to X bps |
   | Redirect VRF | Send to scrubbing VRF |
   | Traffic-marking | Set DSCP |
   | Redirect next-hop | Send to specific IP (scrubber) |

4. **Real-world use:** SP NOC detects DDoS → injects Flowspec rule → all edge routers drop/rate-limit attack traffic matching the 5-tuple — without touching individual router configs.

### Task 9: Flowspec Configuration (IOS-XR Reference)

1. Enable Flowspec address family on all routers:
   ```
   ! IOS-XR syntax (reference):
   router bgp 64512
    address-family ipv4 flowspec
    !
    neighbor 3.3.3.3
     address-family ipv4 flowspec
      route-policy PASS in
      route-policy PASS out
    !
   ```

2. On edge routers — enable Flowspec in hardware:
   ```
   ! IOS-XR:
   flowspec
    address-family ipv4
     local-install interface-all
    !
   ```

3. Inject a Flowspec rule (from controller/trigger router):
   ```
   ! IOS-XR static Flowspec (or via BGP from controller):
   flowspec
    address-family ipv4
     flow DROP-UDP-AMP
      match destination 192.0.2.5/32
      match protocol udp
      match source-port 53
      match packet-length 512-65535
      action traffic-rate 0
     !
   ```

4. **IOS 15.2 (7200) — limited support:**
   ```
   ! IOS 15.x syntax (if supported):
   router bgp 64512
    address-family ipv4 flowspec
     neighbor 3.3.3.3 activate
    exit-address-family
   
   ! Verify:
   show bgp ipv4 flowspec summary
   show bgp ipv4 flowspec detail
   show flowspec ipv4
   ```

### Task 10: Flowspec Use Cases for SP

1. **DNS Amplification DDoS mitigation:**
   ```
   Match: dest=192.0.2.5/32, protocol=UDP, source-port=53, length>512
   Action: drop
   Rationale: legitimate DNS responses are <512 bytes; >512 = amplification
   ```

2. **NTP Amplification:**
   ```
   Match: dest=192.0.2.5/32, protocol=UDP, source-port=123, length>200
   Action: drop
   ```

3. **SYN Flood rate-limit:**
   ```
   Match: dest=192.0.2.5/32, protocol=TCP, tcp-flags=syn, !ack
   Action: traffic-rate 10000000 (rate-limit SYN to 10Mbps)
   ```

4. **Redirect to scrubbing center:**
   ```
   Match: dest=192.0.2.0/24
   Action: redirect-vrf SCRUBBING
   ! Traffic goes to scrubbing VRF → tunneled to Arbor/Radware → clean traffic re-injected
   ```

---

## Section 4: Operational DDoS Response Workflow

### Task 11: Build the NOC Response Playbook

1. **Detection → Classification → Mitigation → Recovery**

   | Phase | Time | Action |
   |---|---|---|
   | Detection | T+0 | NetFlow/sFlow alarm fires: >10Gbps to single /32 |
   | Classification | T+30s | Identify attack vector: UDP amp? SYN flood? HTTP? |
   | Triage | T+1min | Customer impact? Which prefix? Can we scope it? |
   | Mitigation L1 | T+2min | Destination RTBH (if customer accepts downtime) |
   | Mitigation L2 | T+2min | Source-based RTBH (if attacker IPs known) |
   | Mitigation L3 | T+3min | Flowspec rule (surgical filtering) |
   | Mitigation L4 | T+5min | Upstream blackhole (push to transit) |
   | Recovery | T+30min | Remove filters, monitor for re-attack |

2. **Decision tree:**
   ```
   Is victim a single IP?
     YES → S/RTBH first (preserve service for others)
           If source IPs are spoofed/distributed → Flowspec or dest RTBH
     NO → Flowspec (match on protocol/port, not just IP)
   
   Is attack >your capacity?
     YES → Upstream RTBH (push to transit providers)
           OR → redirect to cloud scrubbing (Cloudflare Magic Transit, AWS Shield)
     NO → Handle locally with Flowspec + rate-limit
   ```

### Task 12: Automate RTBH Trigger

1. Script-based trigger (conceptual — integrate with your Python automation from Lab 9/19):
   ```python
   # Pseudocode: inject RTBH via BGP (using ExaBGP or GoBGP)
   def trigger_blackhole(target_ip, community="64512:666"):
       """Inject /32 blackhole route via BGP to RR"""
       announce = f"announce route {target_ip}/32 next-hop self community [{community}]"
       # Send to ExaBGP process peered with R3 (RR)
       exabgp_send(announce)
   
   def remove_blackhole(target_ip):
       """Withdraw blackhole route"""
       withdraw = f"withdraw route {target_ip}/32"
       exabgp_send(withdraw)
   ```

2. Integration with monitoring:
   - NetFlow collector detects anomaly → triggers script → RTBH in <60 seconds
   - Human validates → escalates to Flowspec if needed
   - Auto-expire: remove blackhole after 30 minutes unless re-triggered

### Task 13: Customer-Triggered RTBH

1. Allow customers to trigger blackholes for their own prefixes:
   ```
   ! On PE (R2) — accept blackhole from customer CE (R1):
   router bgp 64512
    address-family ipv4 vrf CUSTOMER-A
     neighbor 192.168.12.1 route-map CUSTOMER-RTBH in
    exit-address-family
   
   ip prefix-list CUSTOMER-A-SPACE permit 192.0.2.0/24 ge 32
   ! Only allow /32 from customer (can't blackhole other people's space)
   
   route-map CUSTOMER-RTBH permit 10
    match ip address prefix-list CUSTOMER-A-SPACE
    match community CUSTOMER-BH-REQUEST
    set community 64512:666 additive
    set local-preference 500
    set ip next-hop 192.0.2.1
   route-map CUSTOMER-RTBH permit 20
    match ip address prefix-list CUSTOMER-A-SPACE
   route-map CUSTOMER-RTBH deny 30
    ! Deny anything outside customer's space
   
   ip community-list standard CUSTOMER-BH-REQUEST permit 65535:666
   ```

2. Customer (R1) triggers their own blackhole:
   ```
   ! On R1 (CE):
   router bgp 65001
    address-family ipv4 unicast
     network 192.0.2.5 mask 255.255.255.255 route-map MY-BLACKHOLE
   
   route-map MY-BLACKHOLE permit 10
    set community 65535:666
   
   ip route 192.0.2.5 255.255.255.255 Null0
   ```

3. **Safety controls:**
   - Only /32 accepted (can't blackhole the whole /24)
   - Only from customer's own prefix space (prefix-list validation)
   - Community must be present (can't accidentally blackhole)
   - Logged and alarmed (NOC visibility)

---

## Section 5: BGP Security — Preventing Hijacks and Leaks

### Task 14: AS-Path Filtering (Prevent Leaks FROM Your Customers)

1. Customer should only advertise their own prefixes. Prevent them from leaking transit routes:
   ```
   ! On R2 (PE, toward customer R1):
   ip as-path access-list 10 permit ^65001$
   ! Only allow routes originated by AS 65001 (empty AS-path after removing 65001 = single origin)
   
   router bgp 64512
    address-family ipv4 vrf CUSTOMER-A
     neighbor 192.168.12.1 filter-list 10 in
    exit-address-family
   ```

2. Also limit prefix count from customer:
   ```
   neighbor 192.168.12.1 maximum-prefix 100 80 restart 30
   ! Customer should have <100 prefixes. Alert at 80%.
   ```

### Task 15: Prevent Route Leaks TO Your Customers

1. Don't send the full table to a single-homed customer (they don't need it):
   ```
   route-map CUSTOMER-OUT permit 10
    ! Only send default route:
    match ip address prefix-list DEFAULT-ONLY
   
   ip prefix-list DEFAULT-ONLY permit 0.0.0.0/0
   
   router bgp 64512
    address-family ipv4 vrf CUSTOMER-A
     neighbor 192.168.12.1 default-originate
     neighbor 192.168.12.1 route-map CUSTOMER-OUT out
    exit-address-family
   ```

### Task 16: BGP Session Security

1. TCP MD5 authentication (already configured in Lab 32):
   ```
   neighbor X.X.X.X password SECURE-KEY
   ```

2. TTL Security (GTSM — Generalized TTL Security Mechanism):
   ```
   ! On R10 (toward Cogent):
   neighbor 198.51.100.2 ttl-security hops 1
   ! Only accept BGP packets with TTL 254 (directly connected)
   ! Prevents remote attackers from establishing BGP sessions
   ```

3. Prefix limit with warning and teardown:
   ```
   neighbor 198.51.100.2 maximum-prefix 500000 90 restart 15
   ```

4. Rate-limit BGP updates (prevent route flap storms):
   ```
   ! IOS-XR style (reference):
   router bgp 64512
    neighbor 198.51.100.2
     address-family ipv4 unicast
      maximum-prefix 500000 90 restart 15
      route-policy DAMPENING in
   ```

---

## Section 6: BGP AIGP (Accumulated IGP Metric)

### Task 17: Understand AIGP (RFC 7311)

1. **Problem:** in multi-AS networks (Option C Inter-AS), BGP loses the end-to-end IGP metric. MED carries metric from one AS but is non-transitive and untrustworthy between different AS operators.

2. **AIGP:** a transitive BGP path attribute that carries the accumulated IGP cost across multiple ASes. Each AS adds its IGP cost to the AIGP value → remote PE can see TRUE end-to-end cost.

3. **Use case:** same organization, multiple ASes (e.g., after acquisitions). Want optimal hot-potato routing across the whole network, not per-AS.

4. Configuration reference:
   ```
   router bgp 64512
    address-family ipv4 unicast
     neighbor 198.51.100.2 aigp
    exit-address-family
   
   route-map SET-AIGP permit 10
    set aigp-metric igp-metric
    ! Adds current IGP cost to the AIGP attribute
   ```

5. **When BGP selects best path:** AIGP is evaluated AFTER LOCAL_PREF and AS-path length, BEFORE MED. If two paths have same LP and AS-path length, lower AIGP wins.

---

## CCIE+ Challenges

### Challenge 1: Selective Blackhole — Blackhole at Specific Edges Only

Customer wants to blackhole 192.0.2.5 only on the Cogent upstream (R10) but NOT on the Lumen upstream (R11). Traffic from Lumen should still reach the victim.

Design a community scheme:
- `64512:6661` = blackhole on R10 only (Cogent edge)
- `64512:6662` = blackhole on R11 only (Lumen edge)
- `64512:6663` = blackhole on R12 only (IXP edge)
- `64512:666` = blackhole everywhere

Implement on all edge routers with community matching.

### Challenge 2: Flowspec with Redirect to Scrubbing VRF

Create a scrubbing architecture:
- VRF `SCRUB` on R10 and R11
- GRE tunnel from `SCRUB` VRF to an external scrubbing appliance (simulate with R20 as scrubber)
- Flowspec rule redirects attacked traffic to VRF `SCRUB`
- Clean traffic re-injected via a different interface
- Document: how do you prevent routing loops when re-injecting clean traffic?

### Challenge 3: Automated DDoS Response with ExaBGP

Design (conceptual + partial implementation):
1. Deploy ExaBGP on a Linux host (or simulate with a router)
2. ExaBGP peers with R3 (RR) as an iBGP speaker
3. Python script monitors sFlow/NetFlow
4. On anomaly detection: ExaBGP injects Flowspec or RTBH route
5. After 30 minutes: auto-withdraw

Document:
- ExaBGP configuration for Flowspec
- Python detection logic (threshold-based)
- How to test without a real DDoS

### Challenge 4: BGP Route Leak Detection

Implement leak detection:
- If you see YOUR OWN prefix (192.0.2.0/21) in a path that shouldn't contain it (e.g., from a peer who shouldn't be transiting), alert.
- Configure:
  ```
  ip as-path access-list 99 permit _64512_
  ! Match any route with AS 64512 in the path
  ! Apply on IXP inbound — if you see YOUR AS from a peer, it's a leak!
  ```
- Build a route-map that logs and optionally rejects these routes

### Challenge 5: Multi-Layer Defense — Combine All Techniques

Scenario: 50Gbps UDP amplification attack against 192.0.2.5/32 from spoofed sources worldwide.

Implement in stages:
1. **T+0:** Destination RTBH (immediate — stop the bleeding)
2. **T+2min:** Push upstream RTBH to Cogent and Lumen (stop at transit edge)
3. **T+5min:** Identify attack is UDP/53 with >512 byte packets → deploy Flowspec (more surgical)
4. **T+6min:** Remove destination RTBH (service restored for non-UDP traffic)
5. **T+10min:** Remove upstream RTBH (Flowspec handles it locally now)
6. **T+60min:** Attack subsides → remove Flowspec rules

Document each step's configuration and verify traffic flow at each stage.

---

## Troubleshooting Checklist

| Symptom | Check | Common Fix |
|---|---|---|
| RTBH route not taking effect | `show ip route <victim>/32` — pointing to Null0? | Check community matching, local-pref, ensure /32 is most specific |
| Blackhole not propagating to ASBR | `show ip bgp <victim>/32` on ASBR | Check iBGP session to RR, route-map applied |
| S/RTBH not dropping attacker | `show ip cef <src> internal` — is it Null0? | Verify uRPF is in loose mode on ingress interface |
| uRPF dropping legitimate traffic | Loose mode should NOT drop if default route exists | Check `allow-default` option; verify no asymmetric routing |
| Flowspec rule not installed | `show bgp ipv4 flowspec` — received? | Check `local-install interface-all` (IOS-XR) or platform support |
| Upstream RTBH not working | Transit provider not dropping? | Verify correct provider community (174:666, 3356:9999, etc.) |
| Customer-triggered blackhole leaking | Other customers affected? | Check prefix-list restricts to customer's own space only |
| Blackhole not auto-expiring | Stale /32 in BGP table? | Implement timer-based withdrawal in automation script |

---

## Key Commands Reference

```
! RTBH:
show ip bgp community 64512:666
show ip route <victim>/32
show ip bgp <victim>/32
show ip cef <victim>/32 [detail]
show ip interface <intf> | include verify

! Flowspec (IOS-XR):
show bgp ipv4 flowspec [summary | detail]
show flowspec ipv4 [detail]
show flowspec afi-all [detail]

! uRPF:
show ip interface <intf> | include verify
show ip cef <source> internal
show cef drop

! BGP Security:
show ip bgp neighbors <addr> | include MD5
show ip bgp neighbors <addr> | include TTL
show ip bgp prefix-list <name>
show ip as-path access-list <number>

! Operational:
show ip bgp regexp _64512_          ! Find your own AS in paths (leak detection)
show ip bgp community 64512:666     ! All blackholed routes
show ip bgp longer-prefixes 192.0.2.0/24  ! Find /32 blackholes within a block
clear ip bgp <addr> soft [in|out]
```

---

## Exam Tips (SPCOR + CCIE-SP)

1. **RTBH is bread and butter** — every SP does this. Know destination AND source-based.
2. **Flowspec vs RTBH:** Flowspec is surgical (match on 5-tuple), RTBH is a sledgehammer (all traffic to/from an IP). Know when to use which.
3. **uRPF modes:** strict (RPF check on specific interface) vs loose (route exists anywhere). Loose + Null0 = S/RTBH. Strict on single-homed customer links.
4. **Community values for upstream blackhole** vary per provider — real-world knowledge expected at CCIE level.
5. **Flowspec validation:** IOS-XR validates that the Flowspec originator has a matching unicast route (prevents unauthorized filtering). Know this for troubleshooting.
6. **AIGP** is niche but appears in CCIE-SP — know it preserves end-to-end metric across AS boundaries.
7. **TTL Security (GTSM):** simple but effective — protects against remote BGP session hijacking. Configure on ALL eBGP sessions.
