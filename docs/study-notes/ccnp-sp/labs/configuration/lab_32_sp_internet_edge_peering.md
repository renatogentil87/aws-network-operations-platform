# Lab 32: SP Internet Edge & Peering Policy — Workbook

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 26 routers — expanded multi-ASN topology (Topology E)
**Prerequisite:** Lab 21 (BGP Fundamentals) complete, Labs 1-2 functional knowledge

**End Goal:** Operate as an SP peering engineer. Configure full BGP Internet edge with upstream transit, private peering, IXP route server, prefix filtering (bogon, IRR, max-prefix), community-based traffic engineering, selective blackholing, and graceful shutdown. By the end, you understand how a Tier-2 SP connects to the Internet, manages peering relationships, and controls inbound/outbound traffic using real-world BGP policy — the core of what CCIE-SP BGP is about.

---

## NEW TOPOLOGY: Topology E — Multi-ASN Internet Edge (26 Routers)

### Why 26 Routers?

Your existing 20 routers are a single-AS MPLS core. For realistic BGP peering, you need:
- **Your SP (AS 64512):** internal core (reuse R2-R8, R13-R18 from existing topology)
- **Transit Provider 1 (AS 174):** simulates a Tier-1 (like Cogent)
- **Transit Provider 2 (AS 3356):** simulates another Tier-1 (like Lumen/Level3)
- **Peer SP (AS 9002):** private peering partner
- **IXP Route Server (AS 65000):** represents an Internet Exchange fabric
- **IXP Peer 1 (AS 13335):** simulates a content network (like Cloudflare) at the IXP
- **IXP Peer 2 (AS 16509):** simulates a hyperscaler (like AWS) at the IXP

### Router Allocation

| Router | Role | AS | Console Port | Loopback |
|---|---|---|---|---|
| **R1** | CE (Customer_A West) — *unchanged* | 65001 | 5009 | 1.1.1.1 |
| **R2** | PE / Internet Edge Router (West) | 64512 | 5000 | 2.2.2.2 |
| **R3** | P / RR (North) | 64512 | 5001 | 3.3.3.3 |
| **R4** | P (Core) | 64512 | 5002 | 4.4.4.4 |
| **R5** | P (Core) | 64512 | 5003 | 5.5.5.5 |
| **R6** | P (Core) | 64512 | 5004 | 6.6.6.6 |
| **R7** | P / RR (South) | 64512 | 5005 | 7.7.7.7 |
| **R8** | PE / Internet Edge Router (East) | 64512 | 5006 | 8.8.8.8 |
| **R9** | CE (Customer_A East) — *unchanged* | 65001 | 5007 | 9.9.9.9 |
| **R10** | **ASBR-1 (Transit uplink to AS 174)** | 64512 | 5008 | 10.10.10.10 |
| **R11** | **ASBR-2 (Transit uplink to AS 3356)** | 64512 | 5010 | 11.11.11.11 |
| **R12** | **ASBR-3 (IXP + Private Peering)** | 64512 | 5011 | 12.12.12.12 |
| **R13-R18** | P/PE (South core) — *unchanged roles* | 64512 | 5012-5017 | existing |
| **R19** | CE (Customer_D) — *unchanged* | 65019 | 5018 | 19.19.19.19 |
| **R20** | CE (Customer_E) — *unchanged* | 65020 | 5019 | 20.20.20.20 |
| **R21** | **Transit Provider 1 — Cogent** | 174 | 5020 | 21.21.21.21 |
| **R22** | **Transit Provider 2 — Lumen** | 3356 | 5021 | 22.22.22.22 |
| **R23** | **Peer SP — Regional ISP** | 9002 | 5022 | 23.23.23.23 |
| **R24** | **IXP Route Server** | 65000 | 5023 | 24.24.24.24 |
| **R25** | **IXP Peer 1 — Content Network (Cloudflare-like)** | 13335 | 5024 | 25.25.25.25 |
| **R26** | **IXP Peer 2 — Hyperscaler (AWS-like)** | 16509 | 5025 | 26.26.26.26 |

### Physical Connectivity Diagram

```
                         ┌──────────────────────────────────────────────────────────┐
                         │                    THE INTERNET                            │
                         │     R21 (AS 174, Cogent)      R22 (AS 3356, Lumen)        │
                         │         │                          │                       │
                         └─────────┼──────────────────────────┼───────────────────────┘
                                   │ eBGP                     │ eBGP
                                   │ 198.51.100.0/30          │ 198.51.100.4/30
                                   │                          │
┌──────────────────────────────────┼──────────────────────────┼────────────────────────────────┐
│  YOUR SP: AS 64512               │                          │                                │
│                                  │                          │                                │
│                           R10 (ASBR-1)              R11 (ASBR-2)                             │
│                              │                          │                                    │
│                              │ iBGP full-table          │ iBGP full-table                    │
│                              │                          │                                    │
│   R2(PE)───R3(RR)───R4───R5───R6───R7(RR)───R8(PE)                                          │
│    │                              │                          │                               │
│   R1(CE)                         R12 (ASBR-3 / IXP Edge)   R9(CE)                           │
│                                   │                                                          │
│   R17(PE)──R13──R14──R15──R16──R18(PE)                                                       │
│    │                               │                                                         │
│   R19(CE)                        R20(CE)                                                     │
│                                                                                              │
└──────────────────────────────────┬───────────────────────────────────────────────────────────┘
                                   │
                         ┌─────────┼──────────────────────────────────────────────┐
                         │   IXP FABRIC (Layer 2 — 198.18.0.0/24)                 │
                         │         │                                               │
                         │    R12 (AS 64512)  ←→  R24 (RS, AS 65000)              │
                         │         │                    │                           │
                         │         ├────────── R23 (AS 9002, Peer SP)              │
                         │         │                    │                           │
                         │         ├────────── R25 (AS 13335, Content)             │
                         │         │                    │                           │
                         │         └────────── R26 (AS 16509, Hyperscaler)         │
                         │                                                         │
                         └─────────────────────────────────────────────────────────┘
```

### Link Addressing

| Link | Router A | IP A | Router B | IP B | Purpose |
|---|---|---|---|---|---|
| Transit 1 | R10 | 198.51.100.1/30 | R21 | 198.51.100.2/30 | eBGP to Cogent |
| Transit 2 | R11 | 198.51.100.5/30 | R22 | 198.51.100.6/30 | eBGP to Lumen |
| R10→Core | R10 | 172.16.10.1/30 | R4 | 172.16.10.2/30 | ASBR to core |
| R11→Core | R11 | 172.16.11.1/30 | R5 | 172.16.11.2/30 | ASBR to core |
| R12→Core | R12 | 172.16.12.1/30 | R6 | 172.16.12.2/30 | IXP edge to core |
| IXP fabric | R12 | 198.18.0.1/24 | — | — | IXP peering LAN |
| IXP fabric | R23 | 198.18.0.23/24 | — | — | Peer SP at IXP |
| IXP fabric | R24 | 198.18.0.24/24 | — | — | Route Server |
| IXP fabric | R25 | 198.18.0.25/24 | — | — | Content network |
| IXP fabric | R26 | 198.18.0.26/24 | — | — | Hyperscaler |
| Private peer | R12 | 203.0.113.1/30 | R23 | 203.0.113.2/30 | Direct PNI to AS 9002 |

### GNS3 Implementation Notes

- **Mac M4 / Dynamips Cisco 7200:** 26 routers × ~350MB RAM each = ~9GB. You have 24GB+ on M4 — fits comfortably if you set each router to 256MB (works fine for BGP-only labs without full CEF tables)
- **Console ports:** R21=5020, R22=5021, R23=5022, R24=5023, R25=5024, R26=5025
- **IXP fabric:** use a GNS3 Ethernet switch connecting R12, R23, R24, R25, R26 on a single broadcast domain (198.18.0.0/24)
- **This is a SEPARATE GNS3 project** — don't modify your existing Topology A. Save as "Topology E — Internet Edge"
- **Shortcut:** you can start with only R2, R3, R4, R5, R6, R7, R8, R10, R11, R12 + R21-R26 (14 routers) for the core BGP labs — add the southern ring (R13-R18) later if needed

### What Each External Router Advertises

| Router | AS | Prefixes Advertised | Purpose |
|---|---|---|---|
| R21 (Cogent) | 174 | Full table simulation: 100.64.0.0/10 (broken into /24s), default route | Transit provider — sends full table or default |
| R22 (Lumen) | 3356 | Same full table + different AS-path lengths | Second transit — test path selection |
| R23 (Peer SP) | 9002 | 203.0.113.0/24, 192.0.2.0/24 (own prefixes) | Private peer — limited routes |
| R24 (RS) | 65000 | Reflects routes from R25 + R26 (transparent RS) | IXP route server — passes communities unchanged |
| R25 (Content) | 13335 | 104.16.0.0/12 (Cloudflare space) | Content at IXP — many /24s |
| R26 (Hyperscaler) | 16509 | 52.0.0.0/8 (AWS space), 3.0.0.0/8 | Cloud at IXP — large blocks |

**Your SP (AS 64512) advertises:** 192.0.2.0/21 (aggregated PI space) toward all peers and transits.

### Simulating a Full Table (on Cisco 7200)

You can't load 900K routes into a 7200. Instead, simulate diversity:
```
! On R21 (Transit 1), advertise 50-100 prefixes with varied AS-paths:
router bgp 174
 network 100.64.1.0 mask 255.255.255.0
 network 100.64.2.0 mask 255.255.255.0
 ... (use a loop in GNS3 startup-config or static routes + network statements)
 
 ! Some routes with long AS-paths (simulate distant origins):
 neighbor 198.51.100.1 route-map ADD-PATH out
 
route-map ADD-PATH permit 10
 match ip address prefix-list DISTANT
 set as-path prepend 7018 3491 2914
route-map ADD-PATH permit 20
```

---

## Section 1: Base eBGP Sessions — Transit and Peering

### Task 1: Configure Transit Session to AS 174 (Cogent)

1. On R10 (ASBR-1):
   ```
   router bgp 64512
    bgp router-id 10.10.10.10
    neighbor 198.51.100.2 remote-as 174
    neighbor 198.51.100.2 description Transit-Cogent
    neighbor 198.51.100.2 password 7 TRANSIT-KEY-1
    !
    address-family ipv4 unicast
     neighbor 198.51.100.2 activate
     neighbor 198.51.100.2 prefix-list BOGON-FILTER in
     neighbor 198.51.100.2 route-map TRANSIT-IN in
     neighbor 198.51.100.2 route-map TRANSIT-OUT out
     neighbor 198.51.100.2 maximum-prefix 500000 90 restart 15
    exit-address-family
   ```

2. On R21 (Cogent sim):
   ```
   router bgp 174
    bgp router-id 21.21.21.21
    neighbor 198.51.100.1 remote-as 64512
    neighbor 198.51.100.1 password 7 TRANSIT-KEY-1
    !
    address-family ipv4 unicast
     neighbor 198.51.100.1 activate
     ! Advertise prefixes:
     network 100.64.1.0 mask 255.255.255.0
     network 100.64.2.0 mask 255.255.255.0
     network 100.64.3.0 mask 255.255.255.0
     network 100.64.10.0 mask 255.255.255.0
     network 100.64.20.0 mask 255.255.255.0
     ! Also advertise a default:
     network 0.0.0.0 mask 0.0.0.0
    exit-address-family
   
   ip route 0.0.0.0 0.0.0.0 Null0
   ip route 100.64.1.0 255.255.255.0 Null0
   ip route 100.64.2.0 255.255.255.0 Null0
   ip route 100.64.3.0 255.255.255.0 Null0
   ip route 100.64.10.0 255.255.255.0 Null0
   ip route 100.64.20.0 255.255.255.0 Null0
   ```

### Task 2: Configure Transit Session to AS 3356 (Lumen)

1. On R11 (ASBR-2):
   ```
   router bgp 64512
    neighbor 198.51.100.6 remote-as 3356
    neighbor 198.51.100.6 description Transit-Lumen
    neighbor 198.51.100.6 password 7 TRANSIT-KEY-2
    !
    address-family ipv4 unicast
     neighbor 198.51.100.6 activate
     neighbor 198.51.100.6 prefix-list BOGON-FILTER in
     neighbor 198.51.100.6 route-map TRANSIT-IN in
     neighbor 198.51.100.6 route-map TRANSIT-OUT out
     neighbor 198.51.100.6 maximum-prefix 500000 90 restart 15
    exit-address-family
   ```

2. On R22 (Lumen sim) — advertise SAME prefixes but with DIFFERENT AS-paths:
   ```
   router bgp 3356
    bgp router-id 22.22.22.22
    neighbor 198.51.100.5 remote-as 64512
    !
    address-family ipv4 unicast
     neighbor 198.51.100.5 activate
     ! Same destinations, different paths:
     network 100.64.1.0 mask 255.255.255.0
     network 100.64.2.0 mask 255.255.255.0
     network 100.64.3.0 mask 255.255.255.0
     network 100.64.10.0 mask 255.255.255.0
     network 100.64.20.0 mask 255.255.255.0
     network 0.0.0.0 mask 0.0.0.0
     ! Routes unique to Lumen:
     network 100.64.50.0 mask 255.255.255.0
     network 100.64.51.0 mask 255.255.255.0
    exit-address-family
   
   ! Make some paths longer (simulate routes learned via peers):
   route-map PREPEND-SOME permit 10
    match ip address prefix-list LONGER-PATH
    set as-path prepend 3356 3356
   route-map PREPEND-SOME permit 20
   ```

### Task 3: Configure IXP Peering

1. On R12 (IXP Edge) — peering with IXP Route Server:
   ```
   interface GigabitEthernet2/0
    description IXP Peering LAN
    ip address 198.18.0.1 255.255.255.0
    no shutdown
   
   router bgp 64512
    ! Route Server session (RS doesn't modify AS-path):
    neighbor 198.18.0.24 remote-as 65000
    neighbor 198.18.0.24 description IXP-RouteServer
    neighbor 198.18.0.24 ebgp-multihop 1
    !
    address-family ipv4 unicast
     neighbor 198.18.0.24 activate
     neighbor 198.18.0.24 prefix-list BOGON-FILTER in
     neighbor 198.18.0.24 route-map IXP-IN in
     neighbor 198.18.0.24 route-map IXP-OUT out
     neighbor 198.18.0.24 maximum-prefix 50000 90
    exit-address-family
   ```

2. On R12 — direct bilateral peer (private peering via IXP LAN):
   ```
   router bgp 64512
    ! Direct peer — not via route server:
    neighbor 198.18.0.25 remote-as 13335
    neighbor 198.18.0.25 description Peer-Cloudflare-Direct
    !
    address-family ipv4 unicast
     neighbor 198.18.0.25 activate
     neighbor 198.18.0.25 prefix-list BOGON-FILTER in
     neighbor 198.18.0.25 route-map PEER-IN in
     neighbor 198.18.0.25 route-map PEER-OUT out
     neighbor 198.18.0.25 maximum-prefix 5000 90
    exit-address-family
   ```

3. On R12 — Private Network Interconnect (PNI) to AS 9002:
   ```
   interface FastEthernet4/0
    description PNI to AS 9002 (Peer SP)
    ip address 203.0.113.1 255.255.255.252
    no shutdown
   
   router bgp 64512
    neighbor 203.0.113.2 remote-as 9002
    neighbor 203.0.113.2 description PNI-PeerSP
    !
    address-family ipv4 unicast
     neighbor 203.0.113.2 activate
     neighbor 203.0.113.2 prefix-list BOGON-FILTER in
     neighbor 203.0.113.2 route-map PNI-IN in
     neighbor 203.0.113.2 route-map PNI-OUT out
     neighbor 203.0.113.2 maximum-prefix 10000 90
    exit-address-family
   ```

### Task 4: Configure IXP Route Server (R24)

1. Route server — transparent mode (doesn't insert own AS, passes communities):
   ```
   router bgp 65000
    bgp router-id 24.24.24.24
    no bgp default ipv4-unicast
    !
    ! All IXP members:
    neighbor IXP-MEMBERS peer-group
    neighbor IXP-MEMBERS ebgp-multihop 1
    neighbor IXP-MEMBERS route-server-client
    !
    neighbor 198.18.0.1 remote-as 64512
    neighbor 198.18.0.1 peer-group IXP-MEMBERS
    neighbor 198.18.0.23 remote-as 9002
    neighbor 198.18.0.23 peer-group IXP-MEMBERS
    neighbor 198.18.0.25 remote-as 13335
    neighbor 198.18.0.25 peer-group IXP-MEMBERS
    neighbor 198.18.0.26 remote-as 16509
    neighbor 198.18.0.26 peer-group IXP-MEMBERS
    !
    address-family ipv4 unicast
     neighbor IXP-MEMBERS activate
     neighbor IXP-MEMBERS route-map PASS-ALL in
     neighbor IXP-MEMBERS route-map PASS-ALL out
    exit-address-family
   
   route-map PASS-ALL permit 10
   ```

   **Note:** On IOS, `route-server-client` + not modifying AS-path makes R24 act as a transparent route server. In real IXPs this is done with BIRD or OpenBGPD, but IOS approximation works for learning.

---

## Section 2: Prefix Filtering — Protecting Your Network

### Task 5: Bogon and Invalid Prefix Filtering

1. Create the bogon filter (apply to ALL eBGP sessions inbound):
   ```
   ip prefix-list BOGON-FILTER seq 5 deny 0.0.0.0/0              ! Default (handle separately)
   ip prefix-list BOGON-FILTER seq 10 deny 0.0.0.0/8 le 32       ! "This network"
   ip prefix-list BOGON-FILTER seq 15 deny 10.0.0.0/8 le 32      ! RFC 1918
   ip prefix-list BOGON-FILTER seq 20 deny 100.64.0.0/10 le 32   ! Shared address (CGN)
   ip prefix-list BOGON-FILTER seq 25 deny 127.0.0.0/8 le 32     ! Loopback
   ip prefix-list BOGON-FILTER seq 30 deny 169.254.0.0/16 le 32  ! Link-local
   ip prefix-list BOGON-FILTER seq 35 deny 172.16.0.0/12 le 32   ! RFC 1918
   ip prefix-list BOGON-FILTER seq 40 deny 192.0.2.0/24 le 32    ! Documentation
   ip prefix-list BOGON-FILTER seq 45 deny 192.168.0.0/16 le 32  ! RFC 1918
   ip prefix-list BOGON-FILTER seq 50 deny 198.18.0.0/15 le 32   ! Benchmarking
   ip prefix-list BOGON-FILTER seq 55 deny 198.51.100.0/24 le 32 ! Documentation
   ip prefix-list BOGON-FILTER seq 60 deny 203.0.113.0/24 le 32  ! Documentation
   ip prefix-list BOGON-FILTER seq 65 deny 224.0.0.0/4 le 32     ! Multicast
   ip prefix-list BOGON-FILTER seq 70 deny 240.0.0.0/4 le 32     ! Reserved
   ip prefix-list BOGON-FILTER seq 100 permit 0.0.0.0/0 le 24    ! Everything else, max /24
   ```

   **Important:** The last line rejects anything more specific than /24 — real Internet has almost no legitimate announcements longer than /24.

2. **For the lab:** since we're using 100.64.x.x (CGN space) for simulated routes, MODIFY the filter to allow it:
   ```
   ! Lab override — remove seq 20, add:
   ip prefix-list BOGON-FILTER seq 20 deny 100.64.0.0/10 ge 25    ! Block /25+ in CGN space, allow /24
   ```

### Task 6: Own-Prefix Protection (Don't Accept Your Own Routes Back)

1. Deny your own prefixes from transit and peers:
   ```
   ip prefix-list DENY-OWN-SPACE seq 5 deny 192.0.2.0/21 le 32
   ip prefix-list DENY-OWN-SPACE seq 10 permit 0.0.0.0/0 le 32
   ```

2. Apply in the TRANSIT-IN route-map:
   ```
   route-map TRANSIT-IN deny 5
    match ip address prefix-list DENY-OWN-SPACE
   route-map TRANSIT-IN permit 10
    set local-preference 100
    set community 64512:1000 additive
   ```

### Task 7: Maximum Prefix Protection

1. Already configured in Task 1:
   ```
   neighbor X.X.X.X maximum-prefix 500000 90 restart 15
   ```
   - **500000:** max prefixes accepted (adjust per peer type)
   - **90:** warning at 90% (log message)
   - **restart 15:** if exceeded, tear down session and retry in 15 minutes

2. Per peer type settings:
   | Peer Type | Max Prefix | Rationale |
   |---|---|---|
   | Transit | 500000 | Full table ~900K, but 7200 can't handle that — use 500K |
   | IXP Route Server | 50000 | All IXP members combined |
   | Direct IXP Peer | 5000 | Single network's prefixes |
   | PNI Peer | 10000 | Regional ISP — moderate |

---

## Section 3: Community-Based Traffic Engineering

### Task 8: Define Your Community Schema

1. Community design for AS 64512:

   | Community | Meaning | Applied Where |
   |---|---|---|
   | 64512:1000 | Learned from Transit | All transit-in routes |
   | 64512:2000 | Learned from IXP RS | Routes via route server |
   | 64512:2100 | Learned from IXP bilateral | Direct IXP peers |
   | 64512:3000 | Learned from PNI | Private peering |
   | 64512:100 | Origin: Customer | Your own customer routes |
   | 64512:666 | Blackhole | Trigger RTBH |
   | 64512:900 | Do not announce to peers | Keep route internal/transit only |
   | 64512:901 | Do not announce to transit | Peer-only routes |

2. Apply communities on ingest:
   ```
   route-map TRANSIT-IN permit 10
    set local-preference 100
    set community 64512:1000 additive
   
   route-map IXP-IN permit 10
    set local-preference 200
    set community 64512:2000 additive
   
   route-map PNI-IN permit 10
    set local-preference 300
    set community 64512:3000 additive
   
   route-map PEER-IN permit 10
    set local-preference 250
    set community 64512:2100 additive
   ```

   **Note:** LOCAL_PREF hierarchy: PNI (300) > IXP bilateral (250) > IXP RS (200) > Transit (100)
   This means: prefer peering routes over transit routes (saves $$).

### Task 9: Outbound Policy — What You Advertise to Whom

1. To transit providers — advertise ONLY your own space (you're paying them):
   ```
   ip prefix-list OUR-SPACE permit 192.0.2.0/21
   
   route-map TRANSIT-OUT permit 10
    match ip address prefix-list OUR-SPACE
    ! Optionally prepend to one transit for inbound TE:
   route-map TRANSIT-OUT deny 999
    ! Deny everything else — don't become transit for peers!
   ```

2. To IXP / peers — advertise your space + customer routes (NOT transit-learned):
   ```
   route-map IXP-OUT permit 10
    match ip address prefix-list OUR-SPACE
   route-map IXP-OUT permit 20
    match community CUSTOMER-ROUTES
   route-map IXP-OUT deny 999
   
   ip community-list standard CUSTOMER-ROUTES permit 64512:100
   ```

3. **Critical rule:** NEVER re-advertise routes learned from one peer to another peer (unless you're providing transit). This prevents you from becoming "free transit":
   ```
   ! Block transit routes from being sent to peers:
   route-map PEER-OUT deny 5
    match community TRANSIT-LEARNED
   route-map PEER-OUT permit 10
    match ip address prefix-list OUR-SPACE
   route-map PEER-OUT permit 20
    match community CUSTOMER-ROUTES
   
   ip community-list standard TRANSIT-LEARNED permit 64512:1000
   ```

### Task 10: Inbound Traffic Engineering — Prepending and Communities to Upstreams

1. Make Cogent the preferred inbound path by prepending on Lumen:
   ```
   ! On R11 (toward Lumen):
   route-map TRANSIT-OUT permit 10
    match ip address prefix-list OUR-SPACE
    set as-path prepend 64512 64512 64512
   ```

2. Send well-known communities to transit for selective announcement:
   ```
   ! Tell Cogent "don't announce to AS 3356" (avoid transit through Lumen via Cogent):
   route-map TRANSIT-OUT permit 10
    match ip address prefix-list OUR-SPACE
    set community 174:3356 additive
    ! 174:3356 = Cogent-specific community meaning "don't export to AS 3356"
   ```

   **Note:** Each transit provider has their own community meanings (documented on their NOC pages). In real life you'd check peeringdb.com or the provider's BGP community guide.

### Task 11: Verify Traffic Engineering

1. Check which path is preferred for a destination reachable via both transits:
   ```
   show ip bgp 100.64.1.0/24
   ! Should see two paths — one via R10 (AS 174), one via R11 (AS 3356)
   ! Best path should be the one with higher LOCAL_PREF or shorter AS-path
   ```

2. Check outbound announcements:
   ```
   show ip bgp neighbors 198.51.100.2 advertised-routes
   ! Only your space (192.0.2.0/21) should appear
   
   show ip bgp neighbors 198.18.0.24 advertised-routes
   ! Your space + customer routes, NOT transit routes
   ```

3. Verify no transit leak:
   ```
   ! On R25 (Cloudflare):
   show ip bgp
   ! Should see 192.0.2.0/21 from AS 64512
   ! Should NOT see 100.64.x.x routes via AS 64512 (that would mean you're transiting)
   ```

---

## Section 4: Graceful BGP Shutdown (RFC 8326)

### Task 12: GSHUT Community for Maintenance

1. Scenario: R10's link to Cogent needs maintenance. Drain traffic before taking it down.

2. Configure GSHUT on R10:
   ```
   ! Send GSHUT to Cogent — tells them to lower LOCAL_PREF for our routes:
   route-map TRANSIT-OUT permit 10
    match ip address prefix-list OUR-SPACE
    set community 65535:0 additive
    ! 65535:0 = GRACEFUL_SHUTDOWN well-known community (RFC 8326)
   
   ! Also lower LOCAL_PREF for routes received from Cogent (drain return traffic):
   route-map TRANSIT-IN permit 10
    set local-preference 0
    set community 64512:1000 additive
   ```

3. Wait for convergence (60-90 seconds), then shut the interface:
   ```
   show ip bgp summary
   ! Verify route counts drop
   
   interface FastEthernet0/0
    shutdown
   ```

4. Verify traffic shifted to R11 (Lumen):
   ```
   ! On R3 (RR):
   show ip bgp 100.64.1.0/24
   ! Only Lumen path should remain
   ```

5. After maintenance, restore:
   ```
   interface FastEthernet0/0
    no shutdown
   
   ! Remove GSHUT from route-map:
   route-map TRANSIT-OUT permit 10
    match ip address prefix-list OUR-SPACE
    no set community 65535:0 additive
   
   route-map TRANSIT-IN permit 10
    set local-preference 100
   ```

---

## Section 5: iBGP Full-Table Distribution

### Task 13: iBGP Sessions from ASBRs to RRs

1. All three ASBRs (R10, R11, R12) need iBGP sessions to BOTH route reflectors:
   ```
   ! On R10:
   router bgp 64512
    neighbor 3.3.3.3 remote-as 64512
    neighbor 3.3.3.3 update-source Loopback0
    neighbor 3.3.3.3 next-hop-self
    neighbor 7.7.7.7 remote-as 64512
    neighbor 7.7.7.7 update-source Loopback0
    neighbor 7.7.7.7 next-hop-self
    !
    address-family ipv4 unicast
     neighbor 3.3.3.3 activate
     neighbor 7.7.7.7 activate
    exit-address-family
   ```

2. On RRs (R3, R7) — add ASBRs as RR clients:
   ```
   ! On R3:
   router bgp 64512
    address-family ipv4 unicast
     neighbor 10.10.10.10 route-reflector-client
     neighbor 11.11.11.11 route-reflector-client
     neighbor 12.12.12.12 route-reflector-client
    exit-address-family
   ```

3. Verify routes propagate from transit to PEs:
   ```
   ! On R2 (PE):
   show ip bgp
   ! Should see external routes via R10/R11/R12 (reflected by R3)
   ```

### Task 14: Default Route Injection vs Full Table

1. Option 1 — Full table to all PEs (like a real SP):
   - All iBGP routes reflected to all PEs
   - PEs can make local traffic-engineering decisions
   - **Cost:** memory on PEs (7200 handles ~200K routes comfortably)

2. Option 2 — Default route only to PEs (saves memory):
   ```
   ! On R3 (RR): inject a default originated from self:
   router bgp 64512
    address-family ipv4 unicast
     default-information originate
   ```

3. Option 3 — Full table to border PEs, default to access PEs:
   ```
   ! Use route-map on RR to filter what non-edge PEs receive
   ! Advanced: use BGP ORF or selective route reflection
   ```

---

## Section 6: RPKI/ROA Concepts (Theory + Config Reference)

### Task 15: Understand RPKI (Resource Public Key Infrastructure)

1. **Problem RPKI solves:** BGP has no built-in mechanism to verify who can originate a prefix. Anyone can announce 1.1.1.0/24 and hijack Cloudflare's traffic.

2. **ROA (Route Origin Authorization):** a signed object saying "AS 13335 is authorized to originate 104.16.0.0/12 with max-length /24"

3. **Validation states:**
   | State | Meaning | Action |
   |---|---|---|
   | Valid | ROA exists and matches | Prefer (raise LOCAL_PREF) |
   | Invalid | ROA exists but DOESN'T match (wrong AS or too specific) | Drop or lower pref |
   | Not Found | No ROA exists | Accept normally |

4. Configuration reference (IOS 15.2+):
   ```
   ! Configure RPKI cache server connection:
   router bgp 64512
    bgp rpki server tcp 192.168.1.100 port 3323 refresh 300
   
   ! Apply validation:
    address-family ipv4 unicast
     neighbor 198.51.100.2 route-map RPKI-VALIDATE in
   
   route-map RPKI-VALIDATE deny 10
    match rpki invalid
   route-map RPKI-VALIDATE permit 20
    match rpki valid
    set local-preference 200
   route-map RPKI-VALIDATE permit 30
    match rpki not-found
    set local-preference 100
   ```

5. **Lab limitation:** 7200 IOS 15.2 may not support RPKI commands. Document for exam readiness — test on IOS-XE 16.x+ (CSR1000v) or IOS-XR when EVE-NG is available.

---

## CCIE+ Challenges

### Challenge 1: Selective Transit — Sell Transit to Customer

Your customer R19 (AS 65019) wants Internet access through your network. Configure:
- R17 (PE) provides full Internet table to R19 via eBGP (inside VRF)
- Alternatively: inject default route into VRF
- R19's routes are tagged with community 64512:100 and advertised to transit providers
- Verify R19 can reach 100.64.1.0/24 through your backbone and transit

### Challenge 2: Conditional Advertisement Based on Upstream Health

If the link to Cogent (R10→R21) goes down:
- Automatically prepend your announcements to Lumen by 3x (make Lumen the backup path appear worse to external peers)
- Use `neighbor X.X.X.X advertise-map ADVERTISE-MAP non-exist-map NON-EXIST`
- Document: how does this help vs hurt during failover?

### Challenge 3: BGP Peer Template vs Peer Groups (Scalability)

Reconfigure all IXP peers using:
- **Peer groups** (old style): `neighbor IXP-PEERS peer-group`
- **Peer templates** (modern): `template peer-policy` and `template peer-session`
- Document the difference in memory usage and update generation
- Which scales better with 500+ IXP peers?

### Challenge 4: Multi-Exit Discriminator (MED) Manipulation at Scale

R23 (Peer SP) has two links to you:
- PNI (203.0.113.x) — preferred for their traffic
- IXP (198.18.0.x) — backup

Configure R23 to:
- Send MED 100 on PNI
- Send MED 200 on IXP
- Verify your router prefers PNI path
- Then: disable `bgp always-compare-med` and show that MED only works between routes from the SAME AS

### Challenge 5: Blackhole Community to Upstream (Customer-Triggered RTBH)

Customer R19 is under DDoS attack on 192.0.2.5/32. Configure:
1. R19 announces 192.0.2.5/32 with community 64512:666 to R17
2. R17 matches the community, sets next-hop to a null route (Null0)
3. The blackhole propagates to transit providers via community:
   - Send to Cogent with community `174:666` (Cogent's blackhole community)
   - Send to Lumen with community `3356:9999` (Lumen's blackhole community)
4. Verify: traffic to 192.0.2.5 is dropped at the transit provider edge (not entering your network at all)

---

## Troubleshooting Checklist

| Symptom | Check | Common Fix |
|---|---|---|
| eBGP session won't establish | `show ip bgp summary` — stuck in Active? | Check IP reachability, AS numbers, password mismatch |
| Routes received but not installed | `show ip bgp` — route in table but not best? | Check LOCAL_PREF, AS-path, next-hop reachable |
| Not advertising your prefix to peers | `show ip bgp neighbors X.X.X.X advertised-routes` | Check route-map OUT permits your prefix |
| Transit routes leaking to peers | Check outbound route-map on peer sessions | Add `deny` for community 64512:1000 in PEER-OUT |
| max-prefix exceeded, session down | `show ip bgp neighbor X.X.X.X` | Wait for restart timer, or `clear ip bgp X.X.X.X` |
| Traffic taking suboptimal path | `show ip bgp <prefix>` — check best path selection | Verify LOCAL_PREF, AS-path length, MED |
| Peer sees routes with your AS prepended | Check outbound route-map for unwanted `set as-path prepend` | Remove prepend from the wrong route-map |

---

## Key Commands Reference

```
! BGP table and path analysis:
show ip bgp [prefix]
show ip bgp summary
show ip bgp neighbors [addr] [advertised-routes | received-routes | routes]
show ip bgp community [community] [exact-match]
show ip bgp regexp _174_

! Filtering verification:
show ip prefix-list [name]
show route-map [name]
show ip bgp filter-list [number]
show ip community-list [name]

! Operational:
clear ip bgp [addr] [soft in | soft out]
debug ip bgp updates [in | out] [neighbor addr]
show ip bgp dampening dampened-paths
show ip bgp rib-failure
```
