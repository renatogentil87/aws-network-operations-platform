# MPLS Fundamentals — Luc De Ghein

**Started:** Jul 17, 2026
**Target:** Jul–Aug 2026

---

## Part 1: MPLS Fundamentals

### Chapter 1: The Evolution of MPLS
- MPLS is BGP Core-free - Routers in the backbone network doesn't need to run BGP, only CE-PE needs to run BGP. In the
backbone network routers can just run IP routing protocols such as OSPF, IS-IS. CE-PE runs BGP.
- Basic idea of traffic engineering is to steer the traffic to the best path, not necessarily the shortest path.

### Chapter 2: MPLS Architecture
- MPLS label is a field of 32-bits with a certain structure.
- First 20 bits in label value
- 21-22 is EXP bits for QoS
- 23 is Bottom of Stack Label. Unless this is the bottom label in the stack, if so this bit is set to 1.
- 24-31- TTL Bit to prevent routing loops
- FEC(Forwarding Equivalent Class): Is a group or a flow of packets that are forwarded along the same path and are treated
the same with regard the forwarding treatment. All packets that belongs to the same FEC gets the same label imposed by
ingress LSR. Basically if there is several packets to the same ip prefix, these packets will get the same label.
At each transit hop, the label changes (swap), but all packets belonging to that FEC still travel together — 
they all get swapped to the same new label at each hop. 
The label value changes per hop, but the path and treatment remain the same for all packets in that FEC.
- LSR creates local binding. It bings a label to IPv4 prefix. LSR then distribute this binding to all its LDP neighbors.
- The incoming label is the label from the local binding on the particular LSR.
- The outgoing label is the label from the remote binding chose by the LSR from all possible remote bindings.


### Chapter 3: Forwarding Labeled Packets
Label Operations:
- SWAP: means the top label in the stack is replaced with another
- PUSH: means the top label is replaced with another and then one more additional label are pushed onto the label stack
- POP: the top label is removed

If ingress LSR receives an IP packet and forwards it as labeled, it is called _IP-to-Label_ forwarding case.
- show ip cef: will show the tag imposed (label)

CEF switching is the only IP switching mode that supports MPLS, it needs to be turned on in Cisco devices with
ip cef command.
- show mpls forwarding-table [network[mask/length]] detail: shows all the labels that change on an already labeled
packet. show mpls forwarding-table 10.200.254.4 detail

- Cisco doesn't load balance labeled packets with IPv4. If there are 2 links, one labeled and another non-labeled,
Cisco use labeled path only.

#### Note:
When you issue the command: "no mpls ip propagate-ttl" on the ingress PE hides the entire MPLS core from end-user traceroute 
by setting MPLS TTL to 255 instead of copying IP TTL. The core becomes invisible — appears as a single hop. 
This is used by SPs for security and topology abstraction. Same principle as cloud networks hiding internal fabric.


#### Reserved Labels
- Label 0-15 are reserved labels. LSR cannot use them in normal case for forwarding packets
- Label 3: Implicit Null Label: An egress LSR assigned implicit null label back to the LSR neighbor to a FEC if it doesn't
want to assign a label to that FEC, thus requesting upstream LSR to perform a pop operation. Implicit Null label is also 
called Penultimate Hop Popping (PHP). Implicit Null label doesn't deliver EXP bit for QoS. It basically tells its
LSR neighbor to pop the label before forwarding the packet, so when the packet arrives at egress LSR, it does only ip lookup.

Ipv4 -> Label -> Label -> Label->Ipv4 <-Implicit Null Egress LSR Ipv4

Note: Cisco only advertises implicit null label for connected routes and summarized routes.

- Label 0: Explicit Null label: Explicit Null Label (O) can deliver EXP bit, QoS. Egress LSR look at label 0, it does a lookup
and forward the packet. This case egress LSR will see the label but it will do two lookups, one for label 0, remove it and then
ip lookup. 
- Explicit null vs implicit null produces identifical traceroute output, the difference is only inside the egress PE forwarding
pipeline - explicit null allows QoS classification via EXP bits before label removal, it never adds an entra hop.
Basically explicit null the egress PE receives the labeled packet with label 0, removes the label, decrement the IP TLL and forwards the packet.

#### Unreserved Labels: 
Because label value has 20 bits, the labels from 16-1,048,575 are used for packet forwarding. 
This is enough for normal IGP prefixes, running OSPF, IS-IS. Cisco default range is 16-100,000.
For BGP you may need more labels due to large prefixes tables, then you need to setup using:
- mpls label range min max 

#### TTL of Labeled Packets:
For SWAP: IP TLL is kept, MPLS TTL is decreased, when it hits the IPv4 look, it decreases the IP TTL.
For POP: Removes the label TTL, and decreases IP TTL
For PUSH: Add the label on top and decreses IP TTL Adding MPLS TTL.

#### MPLS MTU
If you know the number of label a LSP can have, you can modify the MPLS MTU with the command:
- mpls mtu _number_
Let's say 2 label of 4 bytes each would give you MTU of 1508.

#### MPLS Maximum Receive Unit (MRU)
Basically, changes the size that a packet can be forwarded on a link depending on the label operation. 
If POP: it has more room for packet because label was dropped, hence more room for packet.
If PUSH: it has less room as the label is added to the packet.
if SWAP: It doesn't change.

### Chapter 4: Label Distribution Protocol (LDP)
LDP Hello messages are UDP port 646 on multicast address 224.0.0.2
- show mpls ldp discovery detail: See Hello Times and Hold Times
- show mpls interfaces: which interface LDP is enabled
LDP ID is the highest ip on the interface or loopback
LPD ID must be an ip that is in the routing table or else doesn't form LDP neighborship.

LSR tries to open a TCP Connection - port 646 to te other LSR, if it is up they negotiate session parameters, such as:
 - Timer; Label Distribution Method; Virtual Path Identifier (VPI)
 - show mpls ldp neighbor IP detail
 - show mpls ldp parameters

#### Note: 
When a router has multiple links toward another LDP router, the same transport address must be advertised on all 
parallel links that uses the same label space, for example: loopback address.
- mpls ldp discovery transport-address IP
- show mpls ldp/ip bindings - LIB on the LSR
  - in-label: refers to local binding
  - out-label: refers to remote binding
  - LDP identifier can also be found

#### MPLS IGP Syncronization: 
If LDP session has a problem on that interface, OSPF advertises the max cost on that interface to prevent packets from traversing
non-labeled LSP. Once LDP is back up then ospf removes the max metric from the interface and let mpls packets flow normally.
For fast failure detection requires tuned IGP timers or BFD. MPLS convergence time = IDP detection time + SFP computation + LDP update.

#### MPLS IDP Session Protection: 
When a network flaps, LDP and IGP has to establish adjacency and advertise routes and labels all over again.
This can cause outage on a network, and to avoid this you can protect the LDP session as long as there is another path to 
reach that LSR. LDP adjancecy is removed on the port that is down but LDP session stays up through alternate path.
- mpls ldp session protection [vrf name] [for acl] [duration seconds]
You need to setup in both LSR, the other LSR you setup: mpls ldp discovery targeted-hello accept.
When the link between two LSRs goes down, the session stays up so LFIB still have the labels, the traffic flow follows different LSP, 
but once the link is back up, the labels are already there, no need to rebuild the LFIB. Traffic might failover depending on IGP settings.


### Chapter 6: Cisco Express Forwarding (CEF)
- Packets can be forwarded through the router in three basic ways: 1/Process switching, 2/ Interrupt switching, 3/ASIC (application specific integration circuit)
- _Process switching_: the slowest of all switching methods. When switching a packet throguh the router, a Cisco IOS process copies of the packet to CPU memory
and looks up at destination IP in the routing table.
- _Fast Switching_: Build a cache called IP Fast Switching route cache. Some timers govern cache entry. If a packet doesn't traverse the switching 
table for a while its removed from cache.
- Build on demand as packets traverse the router. -- show ip cache verbose to see the cache table.

- _CEF Switching_: Switching table is no longer build on demand, built in advance.
- Each prefix in the routing table has an entry in the CEF switching table at the same time.
- CEF Swtiching has two main data structures: FIB(Forwarding Information Base or CEF table); Adjacency table
- The adjacency table is responsible for MAC or L2 rewrite. The L2 rewrite string contains the new L2 header that is used on the
forwarded frame. For Ethernet, this is the new destination and source mac-address and the ethertype.
- An important aspect of the CEF table is that recursive prefixes are immediatelly used. If, for instance, a BGP prefix is in the routing table and it
points to a BGP next-hop - which is learned via IGP - the BGP prefix is inserted into the CEF table with the next-hop that is learned from recursing 
to the BGP next hop.

- show ip bgp 10.10.10.10 - next-hop 100.100.100.100
- show ip cef 10.10.10.10 - next-hop 2.2.2.2 eth0/0 label 23
- show ip cef 100.100.100.100 - next-hop 2.2.2.2. eth0/0 

_Load Balacing_: 1/Per Packet: The load balancing of all packets is round-robin per packet on the outgoing links.
- ip load-sharing per-packet - and you need to configure this command on all the outbound interfaces if you want to configure per-packet CEF load balancing.
- default behavior is per destination, sourceip, destinationip.
Cisco IOS can load-balance in CEF by hashing the source and destination IP address and pointing the result of that hash to a load sharing table.
- This table holds 16 buckets, each of the 16 hash buckets points to one adjacency, and multiple buckets can point to the same adjacency.
- show ip cef x.x.x.x internal / show ip cef exact-route source_address destination_address 
16 hash buckets exist. These hash bucketd distribute the load of traffic among all possible outgoing paths in the best possible way. 
For example: In the case of 2 outgoing paths, 8 hash buckets are assinged to each outgoing path. In the case of 3 outgoing path, 5 hash buckets
are assigned and one bucket is unassigned.
- Each bucket has an outgoing interface, so for each src+dst it hashes to a bucket, so every packet with that src+dst will go to the same bucket which has the same outgoing interface

---

## Part 2: Advanced MPLS Topics

### Chapter 7 - MPLS VPN
- RD: Route Distinguisher: resolve the problem of having overlapping ip by assigning a unique identifier to destinguish the same prefix from different customers.
- RD is 64-bit field used to make VRF prefixes unique when MP-BGP carries them. 
- Two formats: ASN:nn or ip-address:nn

- RT: Route Target: The communication between sites (Customers A, B, C) is controlled by RTs.
- RT is a BGP extended community that indicates which routes should be imported from MP-BGP into the VRF. 
- Exporting an RT means that the export vpnv4 routes receives an additional BGP extended community
- VRF-to-VRF traffic has two labels in the MPLS network. The TOP label is the IGP label and it is distributed
by LDP or RSVP for TE between all P and PE routers hop by hop. The bottom label is the VPN Label that is advertised
by MP-BGP from PE to PE. P routers use the IGP label to forward the packet to the correct egress PE router. The egress PE
router uses the VPN Label to forward the ip packet to the correct CE router.

- BGP Multiprotocol extensions and capabilities. BGP peers send each other the capabilities that they support. The ones
both peer share can then be used. 
- Sends an Open Message to its peer, it includes the capability optional parameter, listing all capabilities of this BGP peer
- show ip bgp neighbors can show the capabilities

- Multiprotocol Extension for BGPv4 define two new BGP Attributes:
  - Multiprotocol Reachable NLRI
  - Multiprotocol Unreachable NLRI
- These attributes advertise or withdrawn routes. both of them hold two fields. Address Family Identifier (AFI) and 
Subsequent Address Family Identifier (SAFI).
- Basically it tells what is being carried. AFI could be Ipv4, IPv6, AppleTAlk. SAFI can be multicast, ipv4 and label.

#### Note: Only BGP extended communities are sent by default to the vpnv4 neighbors. If you want to use standard communities
you need to use send-community both for the bgp neighbor.

#### Route Reflectors
- An RR is a BGP speaker that reflects routes from other BGP speaker.
- If you want to use RR with MPLS VPN, the RR should reflect vpnv4 prefixes, which carry labels. RRs only change the label if
they become the next-hop for the routes, which they usually do not.
- RRs differ in another way from the other BGP speakers in the MPLS VPN network. They don't inject vpnv4 routes when RT is not
configured for acceptance on the RRs.
- debug ip bgp vpnv4 unicast updates in - shows the capabilities 

RR Group: You can group RR and combine which one accepts routes. This can help scale the network by creating groups of RR
that knows about specific routes.
- bgp rr-group NN
- ip extcommunity-list 1 permit rt 1:1
- ip extcommunity-list 1 deny rt 1:2
This example, the group 1 would receive prefixes from 1:1 but deny from 1:2
-

### Chapter 8: MPLS Traffic Engineering
### Notes
- MPLS TE provides efficient spreading of traffic throghout the network, avoiding underutilized or overutilized link.
- MPLS TE takes into account the configured bandwidth of the links
- MPLS TE takes links attributes into account (delay, jitter, metric)
- MPLS TE adapts automatically to changing bw and links attributes. It's source based routing is applied to the traffic
engineered load as opposed to IP destination-based routing.

A TE tunnel is unidirectional, because LSP is unidirectional and it has the configuration only on the head end LSR and not on the 
tail end LSR of the LSP.
- TE Database is built from the TE information that the link state protocol sends. This database contains all the links that are enabled
for MPLS TE and their characteristics or attributes. From this MPLS TE database, path calculation (PCALC) or Constrained SPF (CSPF) 
calculates the shortest route that still adheres to all constraings(most importantly, BW) from the head end LSR to the tail end LSR.

- RSVP Path Message:
- When a head end router needs to reserve a path it sends a RSVP PATH message to the next-hop. The next P router will put that BW 
in standby and forward upstream another RSVP Path message. When the RSVP PATH reaches the tail-end it respond back with RESV
message and the label = POP/NUMBER, that RESV Message is forwarded back to the head-end router with a label with outgoing interface.
- The head end use CSPF to find the best and use RSVP to reserve the BW along the path

### Note:
- In some Cisco IOS uses default of 75% of BW available on the interface if any given when configuring rsvp interface command.

There are three ways to configure the tunnel: Dynamic, Explicit (Static), and Semi Dynamic
- Dynamic let's the MPLS-TE router define the path based on the requirements configured on tunnel interface and rsvp interface.
It uses info from type-10 LSA(OSPF) to know the BW available and which path can be selected based on the tunnel bw configured. (PCALC)
- Static (Explicit) - The network operator directly define the path the network will take.
- Semi-Dynamic - You let Dynamic select the path but you put constraints into it, such as exclude some paths from its calculation or 
manually define some paths alongside of dynamic.

on RSVP PATH Message there is BW, ERO (Explicit Route Object) add the next hop.

OSPF OPAQUE LSAs
- LSA Type 9 - Link SLA - can only be advertised locally - Opaque Link
- LSA Type 10 - Area LSA - it is advertised all the area - Opaque AREA. It advertises the contraints of the link in the area.
- LSA Type 11 - Inter-Area - can be advertised across areas - Opaque-AS

Type 10 - 2 type of TLV (Type Length Value):
- Route Address TLV: Loopback Address
- Link State TLV: It contains sub-TLVs - these TLVs are interfaces running MPLS TE

Sub TLVS:
- Sub TLV 1: Contains the link type (point-to-point or multiaccess)
- Sub TLV 2: contains the router id neighbor for p2p or DR id for multi-access
- Sub TLV 3:  Local interface IP address
- Sub TLV 4: Remote interface ip address
- Sub TLV 5: Admin Metric - TE Metric, specify the TE metric
- Sub TLV 6: Max BW - max bw can be used on this link, whatever configured with BW command.
- Sub TLV 7: Max reservable BW - default is the same as interface bw
- Sub TLV 8: Unreserved BW - value is the BW can be reserved with different priorities
- Sub TLV 9: Resource Class

RSVP: TSPEC: Tunnel Specifications - we need reserve of 1.200k
- ERO - Explicit Route Object - the path for the packet

Type 10 LSA contains several Links:
- 1.0.0.0 - local link, for example loopback
- 1.0.0.1 - first interface enabled for MPLS - TE
- 1.0.0.2 - Second interface enabled for MPLS TE

### Commands
show mpls traffic-eng tunnels tun0
mpls traffic-eng tunnels
ip rsvp bandwidth RESERVED BW
tunnel mode mpls traffic-eng
tunnel mpls traffic-end bw BW
tunnel mpls traffic-eng path-option NAME/NUMBER Dyamic/Explicit
```

```

---

### Chapter 9: IPv6 over MPLS (6PE/6VPE)

### Notes




### Commands

```

```

---

### Chapter 10: Any Transport over MPLS (AToM)

### Notes




### Commands

```

```

---

### Chapter 11: Virtual Private LAN Service (VPLS)

### Notes




### Commands

```

```

---

**Lab Checkpoint: After Chapters 7–8**

| Lab | What to verify |
|-----|---------------|
| MPLS L3VPN | VRF, RD, RT import/export, PE-CE with BGP & OSPF, MP-BGP VPNv4 |
| MPLS Traffic Engineering | RSVP-TE tunnels, explicit paths, FRR, bandwidth reservation |

---
## Lab 1 Notes: MPLS Forwarding Basics

**Topology:** R1[CE] → R2[PE] → R3/R4/R5/R6/R7[P] → R8[PE] → R9[CE]
**Platform:** GNS3, Cisco 7200 images
**IGP:** OSPF area 0 on all core interfaces, static routes on CE↔PE

### Tests Completed

- [x] LDP adjacency formed (`show mpls ldp neighbor`)
- [x] Labels allocated per IGP prefix (`show mpls forwarding-table`)
- [x] Push at ingress LSR (traceroute from CE shows label imposed)
- [x] Swap at transit (`show mpls forwarding-table` — incoming → outgoing label)
- [x] PHP confirmed (penultimate hop shows "Pop Label")
- [x] ECMP observed in traceroute (multiple paths per probe)
- [x] Confirmed traceroute unreliable with ECMP — use `show mpls forwarding-table` hop-by-hop instead

### Tests To Do — Forwarding Behavior (Chapter 3)

- [x] **Explicit Null vs Implicit Null (PHP)**
  - On R2: `mpls ldp explicit-null`
  - Check R6's forwarding table — should change from "Pop Label" to "Label 0"
  - Proves: EXP/QoS bits preserved to egress LSR
  - Revert: `no mpls ldp explicit-null`

- [x] **TTL Propagation**
  - On R8: `no mpls ip propagate-ttl`
  - Traceroute again — MPLS hops should disappear (only source and destination visible)
  - Proves: hides MPLS infrastructure from external traceroute
  - Revert: `mpls ip propagate-ttl`

- [x] **Labeled vs Unlabeled path preference**
  - Disable `mpls ip` on one link between two routers that have parallel paths
  - Verify traffic uses labeled path only (Cisco won't load-balance labeled + unlabeled)
  - Check with `show ip cef <prefix>` and `show mpls forwarding-table`

- [x] **MPLS MTU impact**
  - `show mpls interface detail` — check MTU values
  - Understand: PUSH reduces room, POP increases room, SWAP no change

### Tests To Do — LDP Behavior (Chapter 4)

- [x] **Link failover / OSPF reconvergence**
  - Shut R5's Fa0/0 (toward R6): `shutdown`
  - Watch: `show mpls forwarding-table 2.2.2.2/32` — does the label path shift?
  - How fast does LDP reconverge? Does it follow OSPF?
  - Bring back up, verify it returns to original path

- [X] **LDP Session Protection**
  - On R5: `mpls ldp session protection`
  - On R6: `mpls ldp session protection` + `mpls ldp discovery targeted-hello accept`
  - Shut the direct link between R5↔R6
  - Verify: `show mpls ldp neighbor` — LDP session stays UP via alternate path
  - Verify: labels for FECs through that neighbor are maintained
  - Proves: session survives link failure, no label re-advertisement needed

- [x] **LDP IGP Synchronization**
  - Under OSPF: `mpls ldp sync`
  - Shut a link, bring it back
  - Observe: OSPF advertises max-metric on that interface until LDP session re-forms
  - `show mpls ldp igp sync` — check state
  - Proves: prevents traffic blackholing during LDP convergence

- [x] **LDP transport address mismatch**
  - On one router: `mpls ldp discovery transport-address interface` (use a non-loopback)
  - Observe: LDP session to that neighbor fails to form
  - `show mpls ldp discovery` — transport addresses don't match
  - Proves: why loopback consistency is critical for LDP

- [x] **Kill MPLS but keep OSPF**
  - `no mpls ip` on one interface
  - OSPF stays up, labels disappear for that path
  - Does traffic still flow via IP? Or does it shift to labeled path only?
  - Proves: Cisco prefers labeled path; removing label forces IP fallback or reroute

- [x] **View all remote bindings (LIB vs LFIB)**
  - `show mpls ldp bindings 2.2.2.2/32`
  - See ALL labels advertised by ALL neighbors for that FEC
  - Only one is installed in LFIB (based on OSPF best path next-hop)
  - Proves: LIB stores everything, LFIB only uses the best

- [x] **LDP ID impact**
  - Change a router's loopback IP (LDP router-id changes)
  - All LDP sessions tear down and re-form
  - Proves: LDP ID must be reachable, and changes are disruptive

### Observations / Lessons Learned

- Traceroute with ECMP is unreliable — each TTL probe can hash to a different path. Use `show mpls forwarding-table` hop-by-hop for truth.
- 

### Key Commands Reference

```
show mpls ldp neighbor [detail]
show mpls ldp discovery [detail]
show mpls ldp bindings [prefix]
show mpls forwarding-table [prefix] [detail]
show mpls interfaces
show mpls ldp igp sync
show ip cef [prefix]
traceroute [dest] source [src] probe 1
show mpls ldp parameters
```
---

## Lab 2 Notes: MPLS L3VPN (Chapter 7)

**Topology:** Same core (R2–R8). Add VRFs on PE routers (R2 and R8). CEs (R1, R9) now run BGP or OSPF with their PE.
**Goal:** Two customers (Customer A, Customer B) sharing the same MPLS backbone, fully isolated.

### What to Configure

- [ ] Create VRFs on R2 and R8: `ip vrf CUSTOMER-A` with RD and RT
- [ ] Assign CE-facing interfaces to VRF: `ip vrf forwarding CUSTOMER-A`
- [ ] Configure MP-BGP between PE routers (R2 ↔ R8) for VPNv4 address family
- [ ] Configure PE-CE routing: BGP (eBGP) or OSPF between CE and PE (inside VRF)
- [ ] Verify end-to-end reachability between CEs in the same VPN
- [ ] Verify isolation — Customer A cannot reach Customer B

### Tests To Do

- [ ] **VRF routing table populated**
  - `show ip route vrf CUSTOMER-A`
  - CE routes should appear via PE-CE protocol

- [ ] **MP-BGP VPNv4 peering established**
  - `show ip bgp vpnv4 all summary`
  - PE routers should be peers, exchanging VPN prefixes

- [ ] **Route Target import/export working**
  - `show ip bgp vpnv4 all`
  - Check RT attached to prefixes, verify import on remote PE

- [ ] **Label stack for VPN traffic (2 labels)**
  - `show mpls forwarding-table vrf CUSTOMER-A`
  - Should see: outer label (LDP, to reach remote PE) + inner label (BGP/VPN, identifies VRF)
  - Traceroute from CE1 should show 2 labels in the stack

- [ ] **Customer isolation**
  - Create VRF CUSTOMER-B with different RD/RT
  - Verify Customer A CEs cannot ping Customer B CEs
  - Verify `show ip route vrf CUSTOMER-B` has no Customer A routes

- [ ] **PE-CE with OSPF (OSPF-to-BGP redistribution)**
  - Change one CE to use OSPF with PE
  - Verify OSPF routes appear in VRF table and get advertised via MP-BGP to remote PE
  - Check OSPF domain-id, down bit (loop prevention)

- [ ] **Shared services / Route Leaking (stretch)**
  - Import RT from both customers into a shared-services VRF
  - Verify shared VRF can reach both customers, but customers can't reach each other

### Key Commands

```
show ip vrf
show ip route vrf <name>
show ip bgp vpnv4 all summary
show ip bgp vpnv4 vrf <name>
show ip bgp vpnv4 all labels
show mpls forwarding-table vrf <name>
show ip bgp vpnv4 all <prefix>
ping vrf <name> <destination>
```

---

## Lab 3 Notes: MPLS Traffic Engineering (Chapter 8)

**Topology:** Same core. Enable TE on all P/PE routers. Build explicit tunnels that avoid the shortest IGP path.
**Goal:** Force traffic through a specific path regardless of OSPF cost.

### What to Configure

- [ ] Enable MPLS TE globally: `mpls traffic-eng tunnels` + under OSPF: `mpls traffic-eng area 0`
- [ ] Enable TE on all core interfaces: `mpls traffic-eng tunnels` under interface
- [ ] Enable RSVP bandwidth on interfaces: `ip rsvp bandwidth <kbps>`
- [ ] Create a TE tunnel on R8: `interface Tunnel0` → explicit path to R2 via non-shortest path
- [ ] Define explicit path: `ip explicit-path name TO-R2-VIA-R3`
- [ ] Route traffic into tunnel: `tunnel mpls traffic-eng autoroute announce`

### Tests To Do

- [ ] **TE tunnel comes UP**
  - `show mpls traffic-eng tunnels`
  - State should be "up", path should match explicit-path

- [ ] **Traffic follows the TE tunnel (not shortest IGP path)**
  - `traceroute` from R8 to R2 — should follow the explicit path
  - Compare with IGP shortest path (should be different)
  - `show ip cef <R2 loopback>` — next-hop should be Tunnel0

- [ ] **RSVP reservation established**
  - `show ip rsvp reservation`
  - `show ip rsvp interface` — verify bandwidth reserved
  - Proves: RSVP-TE signaled the path and reserved resources

- [ ] **Bandwidth constraint**
  - Configure tunnel with `tunnel mpls traffic-eng bandwidth <kbps>`
  - Exceed available bandwidth — tunnel should fail to signal or reroute
  - `show mpls traffic-eng topology` — verify available BW per link

- [ ] **Explicit path vs dynamic path**
  - Create a second tunnel with `path-option 1 dynamic` (no explicit path)
  - Compare: dynamic follows IGP cost, explicit follows your defined hops
  - `show mpls traffic-eng tunnels detail` — compare path options

- [ ] **Fast Reroute (FRR) — link protection**
  - Enable FRR: `tunnel mpls traffic-eng fast-reroute` on the tunnel
  - Configure backup tunnel on a transit router (facility backup)
  - Shut a link in the explicit path — traffic should switch to backup in <50ms
  - `show mpls traffic-eng fast-reroute database`

- [ ] **Autoroute vs forwarding-adjacency**
  - `tunnel mpls traffic-eng autoroute announce` — injects tunnel as next-hop into routing
  - Verify CEF shows Tunnel as outgoing interface
  - Compare with `tunnel mpls traffic-eng forwarding-adjacency` (makes tunnel appear as OSPF adjacency)

### Key Commands

```
show mpls traffic-eng tunnels [brief | detail]
show mpls traffic-eng topology [brief]
show ip rsvp reservation
show ip rsvp interface
show ip explicit-paths
show mpls traffic-eng fast-reroute database
show ip cef <prefix>
show mpls traffic-eng autoroute
```

---

## Lab 4 Notes: L2VPN — AToM + VPLS (Chapters 10–11)

**Topology:** Same core. R2 and R8 as PE. CEs connected via L2 (same broadcast domain across MPLS backbone).
**Goal:** Extend Layer 2 across the MPLS network — CEs think they're on the same LAN.

### What to Configure — AToM (Point-to-Point)

- [ ] Configure pseudowire between R2 and R8: `xconnect <remote-PE-IP> <VC-ID> encapsulation mpls`
- [ ] CE interfaces in the same subnet (they should ARP and communicate directly)
- [ ] No IP address on PE-facing CE interfaces (pure L2 transport)

### What to Configure — VPLS (Multipoint)

- [ ] Create VFI (Virtual Forwarding Instance): `l2 vfi <name> manual`
- [ ] Add neighbors: `neighbor <remote-PE> encapsulation mpls`
- [ ] Bind VFI to a VLAN/bridge-domain
- [ ] Add more than 2 PEs to see full-mesh pseudowire behavior

### Tests To Do

- [ ] **AToM pseudowire UP**
  - `show mpls l2transport vc <VC-ID>`
  - Status should be UP, local and remote labels assigned

- [ ] **L2 connectivity end-to-end**
  - Ping between CEs — they're on the same subnet, same broadcast domain
  - ARP should resolve across the MPLS backbone

- [ ] **Label stack for L2VPN (2 labels)**
  - Outer label: LDP (transport to remote PE)
  - Inner label: VC label (identifies the pseudowire)
  - `show mpls forwarding-table` — verify 2-label stack

- [ ] **VPLS MAC learning**
  - `show bridge-domain` or `show l2 vfi`
  - MAC addresses of remote CEs should appear as learned via pseudowire
  - Verify BUM (Broadcast, Unknown unicast, Multicast) flooding

- [ ] **Pseudowire failover**
  - Shut a link in the core — does the pseudowire reroute via alternate LSP?
  - `show mpls l2transport vc detail` — check status transitions

- [ ] **VPLS full-mesh scaling**
  - With 3 PEs: verify N*(N-1)/2 pseudowires form (3 PEs = 3 PWs)
  - Each PE has a PW to every other PE

### Key Commands

```
show mpls l2transport vc [VC-ID] [detail]
show l2 vfi [name]
show bridge-domain
show xconnect all
show mpls l2transport summary
```

---

## Lab 5 Notes: MPLS QoS + OAM (Chapters 12–14)

**Topology:** Same core.
**Goal:** Verify QoS propagation via EXP bits and test MPLS-specific OAM tools.

### Tests To Do — QoS (Chapter 12)

- [ ] **EXP bit marking at ingress**
  - Apply a policy-map on R8 ingress marking DSCP → EXP
  - `show policy-map interface` — verify packets classified and marked
  - Capture/verify EXP bits in labeled packets

- [ ] **EXP-based queuing at transit**
  - Apply QoS policy on a P router matching on EXP values
  - Different EXP → different queue/treatment
  - Proves: P routers don't look at IP header, only EXP bits for QoS

- [ ] **Explicit Null for QoS preservation (revisit)**
  - With PHP: EXP bits are lost at penultimate hop (label popped)
  - With Explicit Null: egress LSR receives label 0, reads EXP before popping
  - Proves: why Explicit Null matters for QoS-sensitive deployments

### Tests To Do — Troubleshooting (Chapter 13)

- [ ] **LSP Ping**
  - `ping mpls ipv4 <destination-prefix/mask>`
  - Verifies end-to-end LSP connectivity at the MPLS layer (not IP)
  - Proves: the label-switched path is intact

- [ ] **LSP Traceroute**
  - `traceroute mpls ipv4 <destination-prefix/mask>`
  - Shows each LSR hop with incoming/outgoing labels
  - Much more reliable than IP traceroute for MPLS path verification

- [ ] **Debug label operations**
  - `debug mpls packets` (careful — high volume)
  - Verify push/swap/pop happening as expected

- [ ] **Identify broken LSP**
  - Break LDP on one link (`no mpls ip`)
  - Run `ping mpls` — should fail at the broken hop
  - Run `traceroute mpls` — should show where the break is
  - Proves: OAM tools pinpoint MPLS failures better than IP tools

### Tests To Do — OAM (Chapter 14)

- [ ] **MPLS OAM VCCV (Virtual Circuit Connectivity Verification)**
  - For L2VPN pseudowires: `ping mpls pseudowire <peer> <VC-ID>`
  - Verifies the pseudowire path end-to-end

- [ ] **BFD for MPLS (if supported on platform)**
  - Enable BFD on LDP sessions for fast failure detection
  - Proves: sub-second detection of LSP failures

### Key Commands

```
ping mpls ipv4 <prefix/mask>
traceroute mpls ipv4 <prefix/mask>
show mpls traffic-eng autoroute
show policy-map interface
show mpls forwarding-table [detail]
debug mpls packets
ping mpls pseudowire <peer-ip> <vc-id>
```

---

## Lab Summary

| Lab | Triggered After | Key Concepts | Status |
|-----|----------------|--------------|--------|
| **Lab 1: MPLS Forwarding Basics** | Chapters 2–4, 6 | LDP, label allocation, push/swap/pop, PHP, ECMP | 🟡 In Progress |
| **Lab 2: MPLS L3VPN** | Chapter 7 | VRF, RD, RT, PE-CE routing, MP-BGP VPNv4, 2-label stack | ⬜ Not Started |
| **Lab 3: MPLS Traffic Engineering** | Chapter 8 | RSVP-TE, explicit paths, FRR, bandwidth, autoroute | ⬜ Not Started |
| **Lab 4: L2VPN (AToM + VPLS)** | Chapters 10–11 | Pseudowires, xconnect, VPLS, MAC learning, VC labels | ⬜ Not Started |
| **Lab 5: MPLS QoS + OAM** | Chapters 12–14 | EXP bits, LSP ping/traceroute, VCCV, BFD for MPLS | ⬜ Not Started |
