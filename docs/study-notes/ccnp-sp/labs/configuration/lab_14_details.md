# Lab 14: SP Infrastructure Security — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 20 routers — 4 PEs, 9 P routers, 7 CEs. Same topology as previous labs.
**Prerequisite:** Labs 1-2 complete (IGP + MPLS + L3VPN running)

**End Goal:** A hardened SP network where the control plane is protected from attacks, customer traffic cannot reach infrastructure addresses, routing protocols are authenticated, and BGP origin validation is understood. By the end, you have the security posture that SPCOR expects: CoPP, uRPF, infrastructure ACLs, RTBH, and RPKI concepts.

---

## Section 1: Control Plane Policing (CoPP)

### Task 1: Understand the Control Plane Attack Surface

1. On R2 (PE): identify what traffic goes TO the router (not through it):
   - BGP sessions (TCP 179) from CEs and RRs
   - OSPF/IS-IS hellos (protocol 89 or IS-IS)
   - LDP sessions (TCP 646, UDP 646)
   - RSVP signalling (protocol 46)
   - ICMP (ping, traceroute)
   - SSH/Telnet for management (TCP 22/23)
   - SNMP (UDP 161)
2. All of this hits the **route processor (CPU)** — vulnerable to flooding
3. A CE sending millions of packets to R2's interface IP can overwhelm the CPU
4. Without CoPP: a DDoS to the router's IP kills BGP, OSPF, LDP — entire network fails

### Task 2: Build CoPP Class Maps

1. On R2: create class-maps identifying critical control-plane traffic:
   ```
   class-map match-any ROUTING
    match access-group name OSPF-TRAFFIC
    match access-group name BGP-TRAFFIC
    match access-group name LDP-TRAFFIC
   
   class-map match-any MANAGEMENT
    match access-group name SSH-TRAFFIC
    match access-group name SNMP-TRAFFIC
   
   class-map match-any ICMP
    match access-group name ICMP-TRAFFIC
   ```
2. Create the supporting ACLs:
   - `ip access-list extended OSPF-TRAFFIC` → permit ospf any any
   - `ip access-list extended BGP-TRAFFIC` → permit tcp any any eq 179 + permit tcp any eq 179 any
   - `ip access-list extended LDP-TRAFFIC` → permit tcp any any eq 646 + permit udp any any eq 646
   - `ip access-list extended SSH-TRAFFIC` → permit tcp any any eq 22
   - `ip access-list extended SNMP-TRAFFIC` → permit udp any any eq 161
   - `ip access-list extended ICMP-TRAFFIC` → permit icmp any any
3. Verify: `show class-map` — all defined correctly

### Task 3: Apply CoPP Policy Map

1. Create the CoPP policy:
   ```
   policy-map COPP-POLICY
    class ROUTING
     police rate 5000000 conform-action transmit exceed-action transmit
    class MANAGEMENT
     police rate 500000 conform-action transmit exceed-action drop
    class ICMP
     police rate 100000 conform-action transmit exceed-action drop
    class class-default
     police rate 100000 conform-action transmit exceed-action drop
   ```
2. Apply to control plane: `control-plane` → `service-policy input COPP-POLICY`
3. Verify: `show policy-map control-plane` — policy attached
4. ROUTING gets highest rate (never want to drop OSPF/BGP)
5. ICMP and class-default are heavily rate-limited — prevents flood attacks
6. Verify: `ping R2 from R1` still works (ICMP within rate)
7. Generate flood: `ping 172.16.23.1 repeat 100000 timeout 0` from R1 — CoPP should drop excess

### Task 4: Verify CoPP Under Attack Simulation

1. From R1: flood R2's interface with rapid pings:
   - `ping 192.168.12.2 repeat 100000 size 1500 timeout 0`
2. On R2: `show policy-map control-plane` — observe "exceeded" counter increasing under ICMP class
3. Meanwhile: verify BGP session to R8 stays UP (CoPP protects routing from being starved)
4. Verify: `show ip bgp vpnv4 all summary` — all sessions still Established
5. Stop the flood — counters stop increasing
6. **Proves:** CoPP allows legitimate routing while dropping attack traffic
7. Deploy CoPP on ALL PE and P routers (adapt rate limits per role)

---

## Section 2: Unicast Reverse Path Forwarding (uRPF)

### Task 5: Enable uRPF on PE-CE Interfaces

1. On R2's Fa0/0 (toward R1, VRF Customer_A): `ip verify unicast source reachable-via rx`
   - This is **strict mode** — source IP must be reachable via THIS interface
2. On R1: verify normal pings still work (`ping 9.9.9.9 source 1.1.1.1`)
3. On R1: try spoofing — `ping 9.9.9.9 source 200.200.200.200` (address R1 doesn't own)
4. On R2: `show ip verify source` — spoofed packets should be DROPPED
5. Verify: `show ip interface Fa0/0 | include verify` — uRPF active
6. **Why:** prevents CEs from spoofing source addresses (DDoS amplification, attacks on other customers)

### Task 6: uRPF on Core Interfaces (Feasible Path / Loose Mode)

1. On R3's core interfaces: `ip verify unicast source reachable-via any`
   - This is **loose mode** — source IP just needs to exist in the routing table (from any interface)
2. Strict mode on core won't work (asymmetric routing is normal in SP cores)
3. Loose mode catches packets with completely bogus sources (RFC 1918, unallocated, 0.0.0.0)
4. Create an ACL of bogon prefixes and combine with uRPF:
   - `ip access-list extended BOGONS`
   - `deny ip 10.0.0.0 0.255.255.255 any`
   - `deny ip 192.168.0.0 0.0.255.255 any` (if your lab doesn't use these as customer space)
   - `deny ip 127.0.0.0 0.255.255.255 any`
5. Apply as uRPF ACL: `ip verify unicast source reachable-via any allow-default 100` (ACL 100)
6. Verify: traffic with bogon sources is dropped at core ingress

### Task 7: uRPF in VRF Context

1. On R2: uRPF on VRF interface checks against the **VRF routing table** (not global)
2. Verify: R1 can only send packets with sources that exist in Customer_A's VRF
3. R1 tries to source from Customer_B's address space — blocked by uRPF
4. `show ip cef vrf Customer_A source-address 1.1.1.1` — verify RPF check passes
5. `show ip cef vrf Customer_A source-address 12.12.12.12` — should fail RPF (not R1's prefix)
6. **SP model:** uRPF per-VRF ensures customers can only send traffic from their allocated address space

---

## Section 3: Infrastructure ACLs (iACL)

### Task 8: Protect Router Infrastructure Addresses

1. All P routers have loopbacks (3.3.3.3, 4.4.4.4, etc.) and transit link IPs (172.16.x.x)
2. These should NEVER be reachable from CEs — only from within the SP core
3. On R2 (PE ingress from CE): create an infrastructure ACL:
   ```
   ip access-list extended INFRASTRUCTURE-PROTECT
    permit ip any host 192.168.12.2    ! Allow CE to ping PE interface
    deny ip any 172.16.0.0 0.0.255.255 ! Block CE from reaching core transit links
    deny ip any 3.3.3.0 0.0.0.255      ! Block CE from reaching P router loopbacks
    deny ip any 4.4.4.0 0.0.0.255
    deny ip any 5.5.5.0 0.0.0.255
    deny ip any 6.6.6.0 0.0.0.255
    deny ip any 7.7.7.0 0.0.0.255
    permit ip any any                   ! Allow all other traffic (customer-to-customer)
   ```
4. Apply inbound on R2 Fa0/0: `ip access-group INFRASTRUCTURE-PROTECT in`
5. Verify: R1 can still ping R9 (9.9.9.9) — customer traffic passes
6. Verify: R1 CANNOT ping R3 (3.3.3.3) — infrastructure protected
7. Verify: R1 CANNOT ping 172.16.23.1 (core transit link) — blocked

### Task 9: iACL for Management Access

1. Only allow management access from specific management subnet:
   ```
   ip access-list extended VTY-ACCESS
    permit tcp 10.200.0.0 0.0.0.255 any eq 22   ! Management subnet only
    deny ip any any log
   ```
2. Apply to VTY lines: `line vty 0 4` → `access-class VTY-ACCESS in`
3. Verify: SSH from management network works
4. Verify: SSH from CE addresses is blocked
5. Deploy on ALL routers — management access restricted to NOC network only

---

## Section 4: Remotely Triggered Black Hole (RTBH)

### Task 10: Build RTBH Infrastructure

1. On R2 (trigger router): create a static route to Null0 for the attacked prefix:
   - `ip route 1.1.1.1 255.255.255.255 Null0 tag 666`
2. Create a route-map that matches tag 666 and sets community BLACKHOLE:
   - `route-map RTBH-TRIGGER permit 10`
   - `match tag 666`
   - `set community no-export`
   - `set ip next-hop 192.0.2.1` (RFC 5737 documentation address — points to Null0 everywhere)
3. On ALL PEs and P routers: configure a static route for the RTBH next-hop:
   - `ip route 192.0.2.1 255.255.255.255 Null0`
4. Redistribute the tagged static into BGP with the RTBH route-map
5. Verify: the /32 route for 1.1.1.1 propagates via BGP with next-hop 192.0.2.1
6. On R8: `show ip route 1.1.1.1` — next-hop is 192.0.2.1 → Null0 → traffic BLACK-HOLED

### Task 11: Test RTBH Activation and Withdrawal

1. Before RTBH: R9 can ping R1 (1.1.1.1) — normal
2. Activate RTBH: add the static route `ip route 1.1.1.1 255.255.255.255 Null0 tag 666` on R2
3. Wait for BGP to propagate (or `clear ip bgp * soft out`)
4. After RTBH: R9 CANNOT ping R1 — traffic dropped at R8 (or wherever the RTBH route is installed)
5. Verify: `show ip bgp 1.1.1.1` on R8 — next-hop 192.0.2.1, community no-export
6. Withdraw: `no ip route 1.1.1.1 255.255.255.255 Null0 tag 666`
7. After withdrawal: R9 can ping R1 again — black-hole removed
8. **SP use case:** DDoS mitigation. When customer R1 is under attack, SP black-holes traffic TO R1 at the network edge, protecting the core from congestion.

---

## Section 5: Routing Protocol Security

### Task 12: OSPF Authentication (All Interfaces)

1. On ALL core OSPF interfaces: enable MD5 authentication:
   - `ip ospf authentication message-digest`
   - `ip ospf message-digest-key 1 md5 SP-CORE-KEY`
2. Deploy on ALL P and PE routers simultaneously (or area-by-area to avoid adjacency drops)
3. Verify: `show ip ospf neighbor` — all adjacencies still FULL after authentication enabled
4. Test: on one interface, change the key — adjacency drops (proves authentication works)
5. Fix the key — adjacency restores
6. Verify: `show ip ospf interface Gi1/0 | include authentication` — MD5 active

### Task 13: BGP TTL Security (GTSM)

1. On R2: for eBGP sessions with CEs:
   - `neighbor 192.168.12.1 ttl-security hops 1`
2. On R1: `neighbor 192.168.12.2 ttl-security hops 1`
3. This ensures only directly connected peers can establish BGP (TTL must be 254)
4. A remote attacker trying to spoof a BGP session would have TTL < 254 → rejected
5. Verify: session stays UP (directly connected, TTL = 255 → after decrement = 254 → passes)
6. For iBGP sessions (loopback-based): `neighbor 3.3.3.3 ttl-security hops 2` (adjust for hop count)
7. Verify: `show ip bgp neighbors 192.168.12.1 | include TTL` — GTSM enabled

### Task 14: BGP MD5 Authentication

1. On R2 toward R1 (eBGP PE-CE): `neighbor 192.168.12.1 password CUST-A-KEY`
2. On R1: `neighbor 192.168.12.2 password CUST-A-KEY`
3. Verify: session re-establishes with MD5 authentication
4. On R2 toward R3 (iBGP to RR): `neighbor 3.3.3.3 password IBGP-RR-KEY`
5. On R3: `neighbor 2.2.2.2 password IBGP-RR-KEY`
6. Verify: all BGP sessions UP with authentication
7. Misconfigure one key — session drops. Fix — session restores.
8. Deploy on ALL BGP sessions (eBGP and iBGP)

---

## Section 6: RPKI and BGP Origin Validation (Concepts)

### Task 15: Understand RPKI (Theory + Configuration Framework)

1. **RPKI** (Resource Public Key Infrastructure) validates that a BGP prefix is being announced by the authorized AS
2. ROA (Route Origin Authorization): a signed object that says "prefix X.X.X.X/Y is authorized to be originated by AS Z"
3. On R2 (IOS 15.2): configure RPKI validator connection (if supported):
   ```
   router bgp 64512
    bgp rpki server tcp 192.168.1.100 port 8282 refresh 600
   ```
4. If no real RPKI validator available: configure the framework and understand the states:
   - **Valid:** prefix+origin AS matches a ROA → accept
   - **Invalid:** prefix+origin AS contradicts a ROA → drop or depref
   - **Not Found:** no ROA exists → accept (by default)
5. Create a route-map applying RPKI policy:
   ```
   route-map RPKI-POLICY permit 10
    match rpki valid
    set local-preference 200
   route-map RPKI-POLICY permit 20
    match rpki not-found
    set local-preference 100
   route-map RPKI-POLICY deny 30
    match rpki invalid
   ```
6. Apply inbound on eBGP sessions: `neighbor X.X.X.X route-map RPKI-POLICY in`
7. Verify: `show ip bgp rpki table` (if RPKI server reachable) or document the concept
8. **SPCOR expects you to know:** RPKI concepts, ROA validation states, and how to apply policy

### Task 16: BGP Prefix Hijack Simulation

1. On R1 (CE): advertise a prefix you don't own — e.g., `network 8.8.8.0 mask 255.255.255.0`
2. Without RPKI: R2 accepts it and propagates via RR — potential hijack of Google DNS
3. With AS-PATH filter (from Lab 8): blocked because R1's AS-PATH doesn't match
4. With RPKI: would be marked INVALID (8.8.8.0/24 ROA says origin must be AS 15169, not AS 65001)
5. Verify: `show ip bgp 8.8.8.0` on R2 — if RPKI active, shows "invalid" state
6. **Key takeaway:** RPKI + AS-PATH filters + max-prefix = defense-in-depth for BGP security
7. Remove the bogus advertisement from R1

---

## CCIE+ Challenges

### Challenge 1: Comprehensive CoPP Per Router Role

1. Design different CoPP policies for PE vs P routers:
   - PE: allows BGP (iBGP + eBGP), OSPF, LDP, RSVP, SSH, SNMP, ICMP
   - P: allows OSPF, LDP, RSVP, SSH, SNMP, ICMP (no BGP needed on P routers)
2. Deploy appropriate CoPP on each router
3. Verify: flood a PE — BGP stays up. Flood a P — OSPF/LDP stays up.
4. Tune rate limits per class based on expected traffic volumes

### Challenge 2: RTBH with Community-Based Triggering

1. Instead of tag-based triggering, use BGP communities:
   - Community 64512:666 = black-hole the destination
   - Community 64512:667 = rate-limit the destination (instead of full drop)
2. CE sends a route with community 64512:666 to trigger black-hole from customer side
3. PE matches community and installs Null0 route
4. Verify: customer can trigger their own DDoS mitigation by tagging routes
5. **SP service:** "DDoS mitigation on demand" — customer controls black-holing via BGP community

### Challenge 3: Source-Based RTBH (S/RTBH)

1. Standard RTBH drops traffic TO the victim (destination-based) — victim loses all connectivity
2. Source-based RTBH drops traffic FROM the attacker — victim stays online
3. Configure: `ip route <attacker-source> 255.255.255.255 Null0 tag 666`
4. Combine with uRPF at network edge: traffic from attacker source fails RPF check → dropped
5. Verify: legitimate traffic to victim passes, only attacker source is blocked
6. **Advanced SP technique:** surgical DDoS mitigation without sacrificing the victim

### Challenge 4: Secure Template — Full SP Router Hardening

1. Build a complete security template for a P router:
   - CoPP (Task 3)
   - uRPF loose mode on all interfaces (Task 6)
   - OSPF MD5 authentication (Task 12)
   - Infrastructure ACLs (Task 8)
   - VTY access restriction (Task 9)
   - `no ip source-route`
   - `no ip directed-broadcast`
   - `no service tcp-small-servers`
   - `service password-encryption`
   - `login block-for 120 attempts 3 within 60`
2. Build a complete security template for a PE router:
   - All P router items PLUS:
   - BGP MD5 + GTSM on all sessions
   - uRPF strict on CE-facing interfaces
   - Max-prefix on all eBGP sessions
   - AS-PATH filtering on all eBGP sessions
3. Deploy both templates across your network
4. Verify: all security measures active simultaneously without breaking functionality
5. Push via your Python automation (Lab 9) — security at scale

---

## Final Validation

By the end of this lab, your network has:

- [ ] CoPP deployed on all routers (routing traffic prioritized, attacks rate-limited)
- [ ] CoPP proven under simulated flood attack (BGP/OSPF survive)
- [ ] uRPF strict mode on all PE-CE interfaces (source spoofing blocked)
- [ ] uRPF loose mode on core interfaces (bogon sources dropped)
- [ ] Infrastructure ACLs blocking CE access to P router addresses
- [ ] VTY access restricted to management subnet only
- [ ] RTBH infrastructure built and tested (activate/withdraw black-hole in seconds)
- [ ] OSPF MD5 authentication on all core links
- [ ] BGP MD5 authentication on all eBGP and iBGP sessions
- [ ] BGP GTSM (TTL security) on all directly connected eBGP sessions
- [ ] RPKI concepts understood (valid/invalid/not-found states)
- [ ] RPKI policy route-map framework configured
- [ ] BGP prefix hijack prevention (AS-PATH filter + RPKI + max-prefix = defense-in-depth)
- [ ] (CCIE+) Role-specific CoPP (PE vs P router differentiation)
- [ ] (CCIE+) Community-triggered RTBH (customer self-service DDoS mitigation)
- [ ] (CCIE+) Source-based RTBH for surgical attacker blocking
- [ ] (CCIE+) Full security template deployed network-wide via automation
