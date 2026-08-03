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
For example: In the case of 2 outgoing paths, 8 hash buckets are assigned to each outgoing path. In the case of 3 outgoing path, 5 hash buckets
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
- MPLS TE provides efficient spreading of traffic throughout the network, avoiding underutilized or overutilized link.
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

**Semi Dynamic Tunnels**
Two options:1/ Exclude address and 2/Loose Next Hop
 - Exclude a path, so dynamic selects the path but don't use/select another specific path defined on exclude-address. It is used when you don't want to use specific address for some reason.
 - Loose Next Hop: If you have two links or multiple links to the same router, loose next hop will allow the LSR use any link to reach the next-hop.

OSPF DOWN BIT: When a PE router redistribute BGP VPN routes into OSPF (to advertise it to CE when running OSPF (CE-PE)), those routes becomes OSPF LSA.
If CE is connected to another PE that also run OSPF PE-CE, the second PE would learn those routes via OSPF and redistribute them back into BGP creating a loop.
If a PE generates an OSPF LSA from a BGP route, it sets DN Bit (Downward bit) in the LSA option field. This bit says "this route comes from the VPN, not from a real OSPF domain"
- show ip ospf database external x.x.x.x

MPLS TE AUTO BANDWIDTH
Used to prevent waste on BW. When you configure a tunnel with a BW and that BW is not used, auto BW measures the traffic rates on a tunnel, it automatically reduces the BW of a tunnel
and assign more BW to another tunnel. 
- Sampling rate every 300 seconds, it calculates the rate of traffic.
-  Adjustment time - one day by default. It compares the rate of traffic from sampling rates, then auto-bw adjust the higher volume of traffic to the tunnel.
- to prevent issues when traffic is too low and might spike you can configure minimum and maximum values for the bw.
**Configuration**
- Enable Globally - mpls traffic-eng auto-bw timers [frequency]
- interface - tunnel mpls traffic-eng auto-bandwidth
Collect-BW: Auto-bw can measure the traffic tunnels, just calculating the bw, not applying it. Useful when planning to implement auto-bw.

**Affinity and Attribute Flag**
Add an attribute to the link so it can be added or removed from path calculation. Also known as link colouring.
- 32 bits length - hexa character starting from 0x00000000 - 0xffffffff
After configuring attribute-flag you setup the affinity in the tunnel hexa mask hexa.
- When mask = 1 it means the bit is important on attribute flag, if mask =0 not important

0x00000001 - attribute flag - this is equal to - 0000 0000 0000 000 000 000 000 0001 - 1 important bit
0x0000000f - mask - this is equal to - 0000 000 000 000 000 000 000 1111 - mas bit, the last bit is matching which is the important bit.
If the hexa doesn't match the link is excluded from the path calculation.

**NOTE** By default, Cisco IOS doesn't trigger reoptimization when a link in the network is available to TE again, either by configuration or link is operational again.
To enable the optimization when a link becomes operational for MPLS TE: - mpls traffic-eng reoptimize events link-up

MPLS TE Administrative Weight (TE Metrics)
1. IGP Metric
2. TE Metric = IGP Metric by default

R1 - fa0/0 = metric 1 for Fastethernet
TE Metric is the same of IGP metric. MPLS TE always use TE metric to calculate the best path. Lowest TE metric is chosen for TE metric

MPLS TW HOLD AND SETUP PRIORITY
- 8 levels of priority - preferences
- 0 - 7 where 0 is the highest priority and 7 the lowest priority
By default, the setup priority is 7. Assuming a tunnel is using all BW and you configure a second tunnel, the 2nd tunnel doesn't come up.

Tunnel 0 - 500M - SP = 7 = OK = Data Traffic
Tunnel 1 - 500M - SP = 7 = DOWN - Voice Traffic

The priority gives priority to one tunel over another tunnel, for example above, if you chance voice tunnel priority, the tunnel will be prioritised.

HOLD priority is 7 by default
 - Hold priority of tunnel is up status is compared to setup priority of another tunnel that is trying to be established.

Common rule = setup > hold
Setup = 1, Hold = 0 - means " I need priority 1 to establish, but once I'm up, you need priority 0 to displace me"
When a router advertise unreserved BW in LSA or TLV, it sends the unreserved BW with the priority. 
If tunnel0 is 400K and link is 1000M then router advertises different unreserved BW per priority so depending on the BW of the tunnel can be established.

Example of tunnel preemption
Setup:
- Link 1Gbps (1000Mbps Total reservable)
- Tunnel A - hold priority 3, reserved 200Mbps
- Tunnel B - hold priority 6, reserved 600Mbps
- Total reserved = 800Mbps
- Total unreserved = 200Mbps

- Priority 0:
  - Can preempt hold 1,2,3,4,5,6,7
  - Can preempt tunnel A and B - 1000Mbps
- Priority 1:
  - Can preempt hold 2,3,4,5,6,7
  - Can preempt tunnel A and B - 1000Mbps
- Priority 2:
  - Can preempt hold 3,4,5,6,7
  - Can preempt Tunnel A and B - 1000Mbps
- Priority 3:
  - Can preempt hold 4,5,6,7
  - Cannot preempt tunnel A - 200Mbps
  - Can preempt tunnel B = 600 + 200(free) = 800Mbps
- Priority 4:
  - Can preempt hold 5,6,7
  - Can't preemt tunnel A = 200Mbps
  - Can preempt tunnel B = 600 + 200 = 800Mbps

If follows like that until priority 7.

MPLS TE REOPTIMIZATION
- Periodic by default = 1 hour
- Event Driven: When an interface comes back up after failure the tunnel re-routes. If a link change from down to up, the tunnel reoptimize
  - mpls traffic-eng tunnels reoptimize events link-up
- Manual - mpls traffic-eng reoptimization

Feature only for dynamic tunnels
- lockdown feature - we don't want to reoptimize the path, we don't want the change to happen in that tunnel.

MPLS TE AUTOROUTE - Another function to forward traffic to the tunnels, we don't need to configure static route or PBR.
You setup autoroute - mpls traffic-eng autoroute announce on interface and it will be advertise onto the IGP.

MPLS TE Forwarding Adjacency
Forwarding methods so far:
 - Static
 - PBR
 - Autoroute announce
 - Forwarding Adjacency: Create a bidrectional virtual link between head-end and tail-end routers.
You configure two tunnels, from R1 to R4, R4 to R1 then enable forwarding adjacency and they can exchange traffic. It is used for load balancing

OSPF sees the tunnel as a link with IGP metric, other route include this link in CSPF. They can only see it a link when forwarding adjacency is enabled on both directions.

MPLS TE CBTS - CLASS BASED TUNNEL SELECTION
Used for QoS

MPLS LABEL = 32 bits [ Label (32) | EXP (3) | BoS (1) | TTL(8)]
EXP = Experimental  = QoS
BoS = Bottom of Stack
IPP - IP Precedence (IP header has ToS Byte - 8 bit length)
ToS - Type of Service 
- There are 2 important parts
  - IPP = 3 bits = 000,001,010,011,100,101,111 (bigger is better)
  - Bigger EXP faster than lower EXP
  - You can setup which tunnel a exp traffic will flow

QoS - Modular QoS CLI - MQC - ClassMap -> Policy Map ->. Service
Configure a master with member tunnels, the router examine the EXP on each tunnel and define which tunnel to forward the traffic

ToS = 000 = 0 = EXP = 0 
      001 = 32 = EXP = 1
      010 = 64 = EXP = 2
      011 = 96 = EXP = 3
      111 = 128 = EXP 4
      100 = 160 = EXP 5
      101 = 192 = EXP 6
      110 = 224 = EXP 7
- You are not allowed to load-balance traffic with the same EXP bits value onto two different tunnels with CBTS.

MPLS TE - Cost Calculation Process
Equal Cost Load Balancer - if the tunnel and IGP have the same metric, the tunnel will be used. If the destination is behind the tunnel tail then load sharing can be done. 
- Path Weight on output is the TE Metric.

MPLS TE AUTOROUTE ANNOUNCE METRIC
3 types of metrics:
1. Direct: It is the default TE metric (IGP Metric) or the manually configured metric with - tunnel mpls traffic-eng autoroute metric [metric] 
   Metrics behind the tunnel endpoint changes and impact the tunnel metric.
2. Absolute: For all networks behind the tail-end the metric shouldn't change. So when you setup absolute, you shouldn't change the metric to network behind the tail-end.
3. Relative: it means you can add or subtract the metric from IGP cost. For example if metric is 10, you can add 2 or remove 2 from the IGP metric to calculate the best path to a destination.

**MPLS TE QoS Models From IntServ to RSVP-TE**
Techniques used to implement QoS:
1. Best Effort: No QoS at all, all devices should give the best effort to send traffic.

2. IntServ (Integrated Service)- old days to implement it. works with RSVP.
Today QoS we don't use RSVP. All hops of the path works together to give the QoS on the path.

3. DiffServ (Differentiated Service)
It uses a technique called per hop behavior (PHB). Each router doesn't reserve the amount of bw.
It is used Queuing per hop instead and each router can implement a different type of QoS per hop.
Most used QoS today in the networks.
RSVP has another function which is label request. Called RSVP-TE

0 - Explicit Null - php remove the label but keeps EXP bit so php router knows how to treat the QoS for given traffic
- mpls traffic-eng signalling interpret explicit-null verbatim to change to explicit null in MPLS TE
- mpls traffic-eng signalling advertise implicit-null - router will send label 3 (implicit null label)

**RSVP-TE Messages**
RSVP PATH Message:
- RRO - Object that you can enable, you can see the path of RSVP Path, and RESV Message is passing.
- tunnel mpls traffic-eng record-route
- In the path message it records all the ip address that path message is passing through, you can see the path of rsvp path message
- The same can be seen in resv message when returning from path message

Two types of Label Distribution:
1. UD: Unsolicited Downstream: MPLS VPN, MPLS AND MPLS L3VPN uses unsolicited downstream method.
2. DoD: Downstream on Demand: downstream router should request label from the neighbor - Cell Mode MPLS and MPLS TE

When using LDP every LSR should advertise label to its neighbor without any request = UD
In Traffic Engineering, when we enable TE - Routers don't advertise label until requested = DoD - via path message/resv message

Label Distribution protocols: TDP/ LDP / BGP/ RSVP-TE

In MPLS TE we have important concept called Make-Before-Break. It is the ability of having a MPLS tunnel formed before switching the traffic on primary path.
First, it signals the new path, reserve the bandwidth and establish the new path, then it tears-down the first path.
This is called making the tunnel before breaking to prevent traffic being interrupted

Shared Explicit (SE Style)
- We have a tunnel with reserved bw. Old Path of TE LSP
- To establish the need tunnel we need the bw but it is reserved so it can't be established the new path.
That's when Shared Explicit Style comes into place. It's no double booking of bandwidth, the old and new bw requirement is not reserved at the same time.
- Because the shared explicit is running only for one time the Tail End understand the new LSP becomes from the old LSP and understand it can reserved the bw before tearing down the old path.
- The highest amount of bw is used. If old LSP has 1M but new LSP has 2M, only 2M will be used, no need to double booking the BW.

RSVP Messages:
- Path, PathErr, PathTear
- Resv, ResvErr, ResvTear

- Path message: is used to reserve the bandwidth, initial process and then it receveis back the resv message.
- PathErr message: is a message sent toward the head-end router. Used to notify the head-end router the path is not available anymore, it can be due to a link failure between LSP.
LSR can also receive PathErr with bogus information, different vendors, compatibility issues. 
- PathTear message: used when head-end router wants to shutdown the tunnel to other LSR in the path. Let's say we shutdown the tunnel on head end router, we notify other routes
that the link is tearing down. It is sent from head-end towards tail-end router.
- ResvErr Message: sent towards tail-end router, used rarely cases. It can't reserve the amount of bw requested.
- ResvTear Message: It is much like resv message, sent in direction as resv message, towards head-end router. Meaning the router is tearing down the reservation.
We don't need the reservation anymore.

- debug ip rsvp dump-messages to debug the rsvp messages

**Link Manager**
Link Manager is part of Cisco router that does link admission control, keeps track of reserved bw reserved by RSVP.
In Path Message there is TSPEC = 64000 bytes/sec(example). Router needs to validate whether it has the requested bw to send path message forward to next LSR.
1. That's the function of Link Manager control, it controls the admission of the link, it keep tracks of the available bandwidth.
2. Another function of Link Manager, is preemption, it understand the priorities setup for the tunnel to preempt the tunnels.

3. Trigger IGP to flood link state information: 
OSPF (LSA) /ISIS (LSP) - Incremental Update: Router before advertise LSA to R2, only advertise in case there is a change in LSA, then we advertise the new LSA.
The same happens in ISIS (LSP). OSPF advertise the LSAs every 30 minutes, to ensure all routers receive the latest LSAs. Interval Update :30 min OSPF 15 min ISIS.
Routers need to advertise the change in bandwidth usage on the links. It can't be used Interval Updates because of longer convergence time.
There is a mechanism of tune the advertisement the link usage to other routers. If the usage is bigger than 50%, send LSA to other routers. This is function of Link Manager.

- OSPF ->  default is 30 minutes: router(config-router)# timers pacing lsa-group SECs
- ISIS -> default is 15 minutes: router(config-router)# lsp-refresh-internal SECs

Flooding by the IGP - Link Manager send flooding every 3 minutes with contraints of the links. It can be tuned: mpls traffic-eng link-management timers periodic-flooding SEC
1. Link State Change: A link change, interface added or removed from OSPF
2. Configuration Change: manual configuration of interface, cost etc
3. Periodic Flooding
4. Change in the reserved bandwidth: Manually changed the bw or updated bw on the link. 
5. After a tunnel setup failure: we setup the tunnel for a reason failure. The tunnel should be tear down and the bw should be released.


**MPLS TE Fast ReRoute (FRR)**
**Link Protection**
With Link Protection one particular link used for TE is protected. This means that all TE tunnels that are crossing this link are protected by one backup tunnel.
Head-end router has a tunnel with tail end router. It configures a tunnel backup.

R1 -> R2 ---------> R3
          ---R4 --> R3.
Let's say R1 has a tunnel with link protection, R2 is called PLR and R3 MP(Merge Point)
PLR detects the link failure and automatically uses a backup tunnel through a different link, protecting the whole tunnel from head end router to tail end router.
PLR Point of Local Repair
The backup tunnel is also called Next Hop (NHOP). 
When a head-end router of the protected TE tunnel receives the PathErr, it recalculates a new path for the tunnel LSP and signals it.
The backup tunnel doesn't reserve bw, therefore, when protected tunnels use the backup tunnel, it is possible that not enough bw is available to switch the traffic.
Backup tunnel is preconfigured on the PLR router:
- mpls traffic-end backup-path on the protected link
On the head end router of the protected tunnel, you specify that the tunnel can use as a backup tunnel. 
- tunnel mpls traffic-eng fast-reroute
  
! On R3 (PLR) — the transit router
interface Tunnel10 
 tunnel destination 4.4.4.4
 tunnel mpls traffic-eng path-option 1 explicit name BYPASS-R3-R4
 ip unnumbered Loopback0
 tunnel mode mpls traffic-eng
interface FastEthernet0/0              ← R3's interface toward R4 (the protected link)
 mpls traffic-eng backup-path Tunnel10  ← "if this link dies, use Tunnel10"

**Node Protection**
You protect the whole router, not a single link.
It works by creating a NNHOP backup tunnel. When you configure the command - tunnel mpls traffic-end fast-reroute node-protect on the head end router
it sets the flag to Ox10 in the Session Attribute of the PATH message, indicating that it wants node protection

R1 - R2 - R3 - R4 
Let's say R1 has a tunnel with R4. in Link Protection R2 would be PLR in case of a failed link between R2 - R3. R2 would have a tunnel with R4 with explicit path bypassing that r2-r3 connection.
In Node Protection, R2 would bypass completely R3 and tunnel with R4 as backup.
For node protection, when a node fails, the PLR needs to know what label the NNHOP expects and this is done via RRO (Record Route Object) in RSVP
 - show mpls traffic-eng fast-reroute database
shows:
 -  Protected Interface
 - Backup Tunnel
 - Backup Label
 - Protection Type

 - **Example Configuration**
interface Tunnel0
 ip unnumbered Loopback0
 tunnel mode mpls traffic-eng
 tunnel destination 8.8.8.8
 tunnel mpls traffic-eng path-option 1 explicit name VIA-R4
 tunnel mpls traffic-eng fast-reroute node-protect
  
PLR (R3): backup tunnel skips R4 entirely, reaches R5 (next-next-hop):
ip explicit-path name BYPASS-R4-NODE
 next-address 6.6.6.6
 next-address 5.5.5.5
interface Tunnel11
 ip unnumbered Loopback0
 tunnel mode mpls traffic-eng
 tunnel destination 5.5.5.5
 tunnel mpls traffic-eng path-option 1 explicit name BYPASS-R4-NODE
interface FastEthernet0/0
 mpls traffic-eng backup-path Tunnel11

**SRLG - Shared Risk Link Groups**
SRLG is used when a backup tunnel can potentially be routed across a link that is on the same fiber or conduit as the protected link.
If you configure the protected link and all other links that share the same fiber with the same SRLG identifier, the backup tunnel avoids those links.
Two Keywords:
 - force: ensure that backup TE tunnel is never routed over a link that has the same SRLG as the protected link. If a link with another SRLG isn't available tunnel doesn't come up
 - preferred: indicates that if a link with another SRLG is not found first to route the backup tunnel across, the backup tunnel is created across a link with the same SRLG.

- mpls traffic-eng auto-tunnel backup srlg exclude [ force | preferred] (global)
- mpls traffic-end srlg NUMBER (interface level)
- show mpls traffic-end topology brief - see SRLG ids.

**Multiple Backup Tunnel**
Multiple backup tunnels can protect the same link or node, and they can terminate at different tail end routers.
They can be a mix of NHOP and NNHOP. the PLR prefers an NNHOP over a NHOP backup tunnel when assigning a protected TE LSP to a backup tunnel.

**MPLS TE and MPLS VPN**
- RSVP-TE replaces LDP for transport to the tunnel destination only
- BGP still provides the VPN label (always — regardless of LDP or RSVP)
- You keep LDP running for destinations without TE tunnels and as fallback
- In a full-mesh TE deployment (tunnel to every PE), you COULD remove LDP — but most SPs don't

**VRF-to-PE Tunnel**
Traffic from one customer goes to one tunnel and traffic from another customer goes to another tunnel
- The problem is that PE router receives an update with the same next-hop for two different tunnel and end up doing load balacing. To solve this problem you setup two different loopback as next hop so PE router
learns the destination with two different IP addresses to other PE loopbacks.

vrf definition NAME
 address-family ipv4
 bgp next-hop Int_name

That would tell PE to use different next hop for each VRF.

**MPLS VPN PE-to-P Tunnel**
we need to connect customer A to customer A in another site via VRFs, there are multiple paths via IGP.
You can configure TE Tunnel from PE to P tunnel to choose the path to send the traffic to steer the traffic and better usage of the bw depending on the cost of the igp.
The problem of establishing a TE Tunnel from PE to P is that the LSR will POP the label to the tail-end tunnel which is P, and that P won't know how to route the traffic to the destination.
Because they will have only VPNv4 Label.
- For this scenario, there is a must to configure LDP.
- P uses LDP to tell PE (Head End Tunnel) which label is necessary to be used in order to send traffic to P router (tail-end router). 
Now there will be two labels, vpnv4 label, and the LDP label which then allow communication to happen.
1. Solution: enable MPLS on the Tunnel Interface so the tunnel can learn label and how to forward labeled packets to P router.
In the capture, you will have 3 labels, VPNv4 Label, RSVP Label and LDP Label. LDP Label to forward the traffic to P router, RSVP to signaling the tunnel and vpnv4 to carry the vpn label.
2. Solution: Targeted LDP Session: so head-end receives the label from P router and knows how to send the labeled traffic, as long as mpls is also enabled on tunnel interface on head-end router.
   - mpls ldp neighbor x.x.x.x targeted ldp 





### Commands
show mpls traffic-eng tunnels tun0
mpls traffic-eng tunnels
ip rsvp bandwidth RESERVED BW
tunnel mode mpls traffic-eng
tunnel mpls traffic-end bw BW
tunnel mpls traffic-eng path-option NAME/NUMBER Dyamic/Explicit
mpls traffic-eng link-management timers periodic-flooding SEC
show mpls traffic-eng link-management bandwidth-allocation
show mpls traffic-eng link-management addimission-control 


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
| **Lab 1: MPLS Forwarding Basics** | Chapters 2–4, 6 | LDP, label allocation, push/swap/pop, PHP, ECMP | ✅ Complete |
| **Lab 2: MPLS L3VPN** | Chapter 7 | VRF, RD, RT, PE-CE routing, MP-BGP VPNv4, 2-label stack | 🟡 In Progress |
| **Lab 3: MPLS Traffic Engineering** | Chapter 8 | RSVP-TE, explicit paths, FRR, bandwidth, autoroute | 🟡 In Progress |
| **Lab 4: L2VPN (AToM + VPLS)** | Chapters 10–11 | Pseudowires, xconnect, VPLS, MAC learning, VC labels | ⬜ Not Started |
| **Lab 5: MPLS QoS + OAM** | Chapters 12–14 | EXP bits, LSP ping/traceroute, VCCV, BFD for MPLS | ⬜ Not Started |
| **Lab 6: Advanced L3VPN** | Post Chapter 7 | Inter-VRF leaking, hub-spoke VPN, multi-homed CE, SOO | ⬜ Not Started |
| **Lab 7: Advanced TE** | Post Chapter 8 | FRR, affinity bits, preemption, auto-bandwidth | ⬜ Not Started |
| **Lab 8: BGP Design** | Post Book 2 | Route Reflectors, communities, path manipulation | ⬜ Not Started |
| **Lab 9: Automation** | Ongoing | Python provisioning, state collection, validation | 🟡 In Progress |

---

## Lab 6 Notes: Advanced L3VPN Scenarios

**Topology:** Full 20-router topology. 4 PEs (R2, R8, R17, R18), multiple customers across VRFs.
**Goal:** Production-level VPN designs beyond basic connectivity.

### Tests To Do

- [ ] **Inter-VRF Route Leaking (Shared Services)**
  - Create VRF Shared_Services on one PE
  - Import RT from Customer_A AND Customer_B into Shared_Services VRF
  - Export Shared_Services RT, import it into Customer_A and Customer_B
  - Verify: shared services VRF can reach both customers
  - Verify: Customer_A still cannot reach Customer_B directly

- [ ] **Hub-and-Spoke VPN**
  - One CE is the hub (e.g., R1), others are spokes (R9, R11)
  - Hub PE exports with RT 64512:100, imports RT 64512:200
  - Spoke PEs export RT 64512:200, import RT 64512:100
  - Verify: spokes can reach hub, spokes cannot reach each other directly
  - All spoke-to-spoke traffic goes through the hub

- [ ] **Multi-homed CE (dual PE)**
  - Connect one CE to two PEs (e.g., R1 connected to both R2 and R17)
  - Run eBGP to both PEs
  - Verify: traffic uses best path, failover works if one PE-CE link drops
  - Test: AS-PATH manipulation to prefer one PE over the other

- [ ] **SOO (Site of Origin) — loop prevention**
  - On multi-homed CE scenario above
  - Configure `set extcommunity soo 64512:1` on both PE-CE sessions for R1
  - Verify: R1's routes advertised to R2 don't come back to R1 via R17
  - Proves: prevents routing loops with multi-homed sites

- [ ] **Internet Access for VPN Customer**
  - Inject default route into VRF Customer_A on one PE
  - `default-information originate` or static `0.0.0.0/0` in VRF redistributed into BGP
  - Verify: CE can reach "internet" (simulate with a loopback in global table)
  - Verify: only the intended VRF gets the default route

- [ ] **PE-CE with OSPF (one site BGP, another OSPF)**
  - R1 uses eBGP to R2 (already done)
  - Change R9 to use OSPF with R8: `router ospf 2 vrf Customer_A`
  - Redistribute OSPF into BGP VRF, and BGP into OSPF
  - Verify: R1 and R9 can still reach each other
  - Check OSPF domain-id, DN bit (down bit) for loop prevention

### Key Commands

```
show ip vrf detail
show ip bgp vpnv4 all community
show ip extcommunity-list
show ip route vrf <name> | include source-of-origin
show ip bgp vpnv4 vrf <name> <prefix>
```

---

## Lab 7 Notes: Advanced MPLS TE

**Topology:** Same core. Multiple TE tunnels with different constraints.
**Goal:** Production-level TE designs beyond basic explicit paths.

### Tests To Do

- [ ] **Fast Reroute (FRR) — link protection**
  - Enable on tunnel: `tunnel mpls traffic-eng fast-reroute`
  - Create backup tunnel on transit router (next-hop or next-next-hop backup)
  - Shut a link in the primary path
  - Verify: traffic switches to backup in <50ms (compare with path-option failover ~2 seconds)
  - `show mpls traffic-eng fast-reroute database`

- [ ] **Affinity / Attribute Bits (link colouring)**
  - Assign colours to links: `mpls traffic-eng attribute-flags 0x1` (red), `0x2` (blue)
  - Tunnel avoids red links: `tunnel mpls traffic-eng affinity 0x0 mask 0x1`
  - Tunnel prefers blue links: `tunnel mpls traffic-eng affinity 0x2 mask 0x2`
  - Verify: CSPF excludes/includes links based on affinity
  - Use case: avoid satellite links, prefer low-latency paths

- [ ] **Preemption (setup/hold priority)**
  - Tunnel A: priority 7 7 (low priority, setup 7 hold 7)
  - Tunnel B: priority 0 0 (high priority)
  - Both request bandwidth that exceeds a shared link's capacity
  - Verify: Tunnel B preempts Tunnel A (kicks it off the link)
  - Tunnel A falls to backup path or goes down
  - `show ip rsvp reservation` — check which tunnel holds the reservation

- [ ] **Auto-Bandwidth**
  - `tunnel mpls traffic-eng auto-bw max-bw 500000 min-bw 1000`
  - Generate traffic through the tunnel (ping flood or similar)
  - Watch tunnel adjust bandwidth reservation over time
  - `show mpls traffic-eng tunnels tun0 | include auto-bw`
  - Proves: tunnel adapts to actual demand without manual intervention

- [ ] **Load-sharing between TE tunnels**
  - Two tunnels to same destination, both with `autoroute announce`
  - Verify CEF load-balances across both tunnels
  - `show ip cef <destination> internal` — should show both tunnels in hash buckets
  - Test with different bandwidth values: `tunnel mpls traffic-eng load-share`

- [ ] **TE Metric vs IGP Metric**
  - Set different TE metric on a link: `mpls traffic-eng administrative-weight 1000`
  - Dynamic tunnel should now avoid that link (TE metric is worse)
  - IGP routing unchanged (regular traffic still uses IGP metric)
  - Proves: TE path calculation independent from IGP path calculation

### Key Commands

```
show mpls traffic-eng fast-reroute database
show mpls traffic-eng topology | include attribute
show ip rsvp reservation detail
show mpls traffic-eng tunnels [name] detail
show mpls traffic-eng tunnels auto-bw
show mpls traffic-eng link-management bandwidth-allocation
```

---

## Lab 8 Notes: BGP Design

**Topology:** Full 20-router topology. Convert from full-mesh iBGP to Route Reflectors.
**Goal:** Scalable BGP design for SP/enterprise MPLS networks.

### Tests To Do

- [ ] **Route Reflectors (replace full-mesh iBGP)**
  - Designate R3 and R7 as Route Reflectors (redundancy)
  - All PEs (R2, R8, R17, R18) peer with RRs only (not each other)
  - `neighbor <PE> route-reflector-client` on the RRs
  - Remove direct PE-to-PE iBGP sessions
  - Verify: vpnv4 routes still reach all PEs via RR reflection
  - Check: ORIGINATOR_ID and CLUSTER_LIST attributes

- [ ] **RR Cluster design**
  - R3 and R7 in the same cluster: `bgp cluster-id 1`
  - Verify: redundancy works — shut R3, routes still reflected via R7
  - Verify: no routing loops (cluster-list prevents)

- [ ] **BGP Communities for Policy**
  - CE R1 tags routes with community 64512:100
  - PE R8 applies policy: routes with 64512:100 get local-pref 200
  - Verify: traffic from R8 side prefers routes tagged by R1
  - `show ip bgp vpnv4 vrf Customer_A community 64512:100`

- [ ] **BGP Best Path Manipulation**
  - Multi-homed CE connected to R2 and R17
  - Use local-pref to prefer R2 path (set higher on R2)
  - Use AS-PATH prepend to make R17 backup (CE prepends on R17 link)
  - Verify: traffic flows via R2, failover to R17 when R2 link down

- [ ] **BGP Graceful Restart**
  - Enable on PE: `bgp graceful-restart`
  - Shut the BGP session on one PE — routes should be retained for restart timer
  - Verify: traffic continues flowing during restart period
  - Proves: no traffic loss during planned PE maintenance

- [ ] **Conditional Route Advertisement**
  - PE advertises a route to CE only if another route exists (e.g., only advertise default if VPN routes exist)
  - `neighbor <CE> advertise-map ADV condition-map COND`
  - Verify: remove condition route — advertisement withdraws

### Key Commands

```
show ip bgp vpnv4 all summary
show ip bgp vpnv4 all
show ip bgp neighbors <ip> | include Cluster|ORIGINATOR
show ip bgp community <community>
show ip bgp vpnv4 all neighbors <ip> advertised-routes
show ip bgp vpnv4 all neighbors <ip> routes
debug ip bgp updates
```

---

## Lab 9 Notes: Python Automation

**Topology:** All 20 routers via GNS3 telnet.
**Goal:** Automate provisioning, state collection, and validation.

### Tests To Do

- [x] **Push MPLS base config to all P routers** (Jinja2 + Netmiko)
- [x] **Push PE VRF config** (Jinja2 template + inventory)
- [x] **Push CE config** (Jinja2 template)
- [x] **Dry-run mode** (render and print without pushing)
- [ ] **New customer VRF provisioning**
  - Add new customer to inventory (VRF name, RD, RT, CE interface, CE AS)
  - Run push_config → new VRF appears on all relevant PEs
  - Verify with show commands automatically after push

- [ ] **State collector: OSPF neighbors**
  - Connect to all P routers, run `show ip ospf neighbor`
  - Parse output, report which adjacencies are Full vs not
  - Alert if any neighbor is missing

- [ ] **State collector: LDP neighbors**
  - Connect to all P/PE routers, run `show mpls ldp neighbor`
  - Parse Peer LDP Ident and Up Time
  - Report all neighbors and flag any that are down

- [ ] **State collector: BGP VPNv4 summary**
  - Connect to all PEs, run `show ip bgp vpnv4 all summary`
  - Parse neighbor state and prefix count
  - Alert if any PE has 0 prefixes received

- [ ] **State collector: TE tunnel status**
  - Run `show mpls traffic-eng tunnels brief` on head-end PEs
  - Parse tunnel state (up/down, which path-option active)
  - Report any tunnels that are down or on backup path

- [ ] **Validator: Full health check**
  - Run all collectors
  - Compare against expected state (all OSPF Full, all LDP up, all tunnels up, all BGP sessions established)
  - Print summary: PASS/FAIL per check

- [ ] **Config backup**
  - Connect to all 20 routers, run `show running-config`
  - Save each to a file: `configs/R1.cfg`, `configs/R2.cfg`, etc.
  - Version control in git — run before and after changes

### Key Files

```
python/netops/configurator/push_config.py
python/netops/configurator/inventory.yaml
python/netops/configurator/templates/*.j2
```
