# ENCOR 350-401 — Cisco Enterprise Network Core Technologies

**Started:**
**Target:** Ongoing reference + deep study when OSPF/IS-IS/EIGRP topics arise in labs

---

## OSPF (OSPFv2 / OSPFv3)

### Notes

- OSPF finds the lowest cost path, not the shortest path. Shortest Path First means shorted weighted path in graph topology
with minimum cumulative cost, no fewest steps.
- Cost = reference-bw / interface-bw
- ECMP happens when total end-to-end cost is equal, not when individual link costs are equal. A cheap first hope + expensive
later hops can equal an expensive first hop + cheap later hops.
- OSPF cost is per-interface, per-router, outbound direction only. Each router makes its own independent forwarding decision.
This means traffic can take different physical paths in each direction (asymmetric routing).


### OSPF Neighbor States
- Down: No hellos received from its neighbor
- Init: Hello receive, but neighbor hasn't acked us yet (our router-id isn't in their Hello)
- 2-Way: Mutual hello exchanged confirmed (both routers see each other route-ids in hellos) DR/BDR election happens here
- ExStart: Master/Slave negotiation happens for database exchange (who goes first, agree on sequence number)
- Exchange: Database Description packets exchanged - each router describes its LSDB - it doesn't exchange the full database, it exchanges
a summary (DBD packets listing LSAs headers). Then in loading exchange the full LSA.
- Loading: LSRs (Link-State Requests) sent for any LSAs the neighbor has that we don't
- Full: We are in sync, adjancency is complete

The logic is discover, negotiate master/slave, compare databases, transfer missing LSAs, syncronized.
- Stuck in init: one-way communication
- Stuck at ExStart/Exchange: MTU mismatch
- 2-Way between DROHER is normal

#### OSPF + MPLS Underlay:
- MPLS convergence is only as fast as IGP convergence. LDP has no indepeendent failure detection - it's a slave to the IGP.
- Interface DOWN - instant detection (no dead timer). Neighbor silent on a live link = must wait for dead timer (default 40 seconds)
- mpls ldp igp sync solves the recovery race condition (labels are not ready whe OSPF advertises the link), not detection speed
- Fast failure detection requires tuned IGP timers (Hello 1, Dead 3) or BFD

### OSPF LSA Types




### OSPF Area Types (Stub, NSSA, Totally Stub)




### OSPF + MPLS Underlay Insights




### OSPF vs IS-IS for SP/MPLS Underlay




### Commands

```

```

### Lab Notes




---

## IS-IS

### Notes




### IS-IS vs OSPF — Trade-offs for MPLS Underlay




### Commands

```

```

### Lab Notes




---

## EIGRP

### Notes




### Commands

```

```

### Lab Notes




---

## Route Redistribution

### Notes




### Commands

```

```

### Lab Notes




---

## Path Control (PBR, IP SLA)

### Notes




### Commands

```

```

### Lab Notes


