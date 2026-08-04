# Troubleshooting Lab 6: MPLS Traffic Engineering Advanced — 20 Tickets

**Platform:** GNS3 Local (Cisco 7200, IOS 15.2)
**Topology:** 14 routers — 4 PEs (R1, R5, R9, R14), 8 P routers, 2 CEs
**Difficulty:** CCNP-SP to CCIE-SP progressive

---

## Lab Rules

- Do NOT change hostnames, enable passwords, or console/VTY configuration
- Do NOT change IGP areas or AS numbers
- Do NOT add new interfaces or IP addresses unless explicitly required
- Do NOT remove existing features to resolve a ticket — fix the root cause
- Static routes are NOT permitted unless preconfigured
- Points are awarded for finding AND resolving the fault
- The resolution of one ticket MAY depend on previous tickets
- There are NO physical faults (all interfaces are cabled correctly)
- Use password `cisco` for any authentication if needed

---

## Topology Reference

| Role | Routers |
|---|---|
| PE (headend) | R1, R14 |
| PE (tailend) | R5, R9 |
| P (core-north) | R2, R3, R4 |
| P (core-south) | R6, R7, R8 |
| P (cross-connect) | R10, R11 |
| CE | R20 (AS 65001), R21 (AS 65002) |

**TE Tunnels (pre-configured):**
- Tunnel0: R1→R5 (dynamic, BW 50000, autoroute)
- Tunnel1: R1→R9 (explicit via north path: R2→R3→R4→R9, BW 80000)
- Tunnel2: R14→R5 (dynamic, BW 30000, FRR protected)
- Tunnel3: R14→R9 (affinity-constrained, BW 60000)

**IGP:** OSPF Area 0 with TE extensions
**RSVP:** Bandwidth 100000 on all core interfaces
**Affinities:** Links R6-R7, R7-R8 colored "gold" (0x1); all others "standard" (0x0)

---

## Ticket 1

Tunnel0 on R1 (dynamic path to R5) is DOWN. The MPLS TE topology database on R1 shows all routers and links. RSVP signaling is not reaching the tailend. Debug shows "no path found."

Fix the network so that Tunnel0 comes UP with a valid dynamic path.

Verify: `show mpls traffic-eng tunnels tunnel0` shows state UP with a valid ERO.

Score: 2 Points

---

## Ticket 2

Tunnel1 on R1 (explicit path R2→R3→R4→R9) is DOWN with "path not found." The explicit path is configured with strict hops. All routers on the path are reachable and TE-enabled.

Fix the network so that Tunnel1 signals successfully on its explicit path.

Verify: `show mpls traffic-eng tunnels tunnel1` shows state UP with the path R1→R2→R3→R4→R9.

Score: 2 Points

---

## Ticket 3

Tunnel2 on R14 is UP but with 0 bandwidth reserved. The tunnel was configured to request 30000 kbps but admission control is not reserving bandwidth on the path. RSVP shows "admitted" but with BW=0.

Fix the network so that Tunnel2 reserves its requested bandwidth along the path.

Verify: `show mpls traffic-eng tunnels tunnel2` shows bandwidth 30000. `show ip rsvp reservation` on path routers shows the BW allocated.

Score: 2 Points

---

## Ticket 4

Tunnel3 on R14 requires affinity "gold" links (bit 0x1 set). The tunnel is DOWN because CSPF cannot find a path that satisfies the affinity constraint. However, the gold-colored links (R6-R7, R7-R8) exist and have available bandwidth.

Fix the network so that Tunnel3 uses the gold-affinity path and comes UP.

Verify: `show mpls traffic-eng tunnels tunnel3` shows state UP with path through R6→R7→R8 (gold links).

Score: 3 Points

---

## Ticket 5

RSVP bandwidth reservation on link R3→R4 is at 100% (fully reserved). A new tunnel requesting bandwidth on this link is being rejected. However, `show mpls traffic-eng link-management bandwidth-allocation` shows that the reservations don't match actual tunnel usage — phantom reservations exist from a torn-down tunnel.

Fix the network so that stale RSVP reservations are cleared and legitimate tunnels can reserve bandwidth.

Verify: `show ip rsvp reservation` on R3 shows only active tunnel reservations. The new tunnel can signal through R3→R4.

Score: 3 Points

---

## Ticket 6

Tunnel0 is UP but using a suboptimal path (6 hops instead of the shortest 3 hops). The path avoids links that have available bandwidth and TE enabled. The TE topology database shows all links correctly, but CSPF is computing a long path.

Fix the network so that CSPF selects the shortest path with available bandwidth.

Verify: `show mpls traffic-eng tunnels tunnel0` shows the shortest path (3 hops). `show mpls traffic-eng topology` confirms all links visible with correct TE metrics.

Score: 3 Points

---

## Ticket 7

RSVP refresh reduction is not working between two P routers. RSVP state is timing out every 30 seconds, causing brief tunnel flaps. Both routers have refresh reduction configured but the summary-refresh messages are being rejected.

Fix the network so that RSVP refresh reduction works and state is maintained without full refresh timeouts.

Verify: `show ip rsvp` shows refresh reduction active. Tunnels remain stable without periodic flaps.

Score: 2 Points

---

## Ticket 8

TE tunnel auto-bandwidth is configured on Tunnel0 but it's not adjusting. The tunnel was provisioned at 50000 kbps but actual traffic is only 5000 kbps. Auto-bandwidth should have adjusted down to save reservable bandwidth for other tunnels. The adjustment interval has passed multiple times.

Fix the network so that auto-bandwidth adjusts the tunnel bandwidth based on measured traffic.

Verify: `show mpls traffic-eng tunnels tunnel0` shows adjusted bandwidth closer to actual usage (after the next interval). `show mpls traffic-eng tunnels tunnel0 auto-bw` shows bandwidth sampling working.

Score: 3 Points

---

## Ticket 9

Tunnel2 has FRR (Fast Reroute) configured (facility backup). A backup tunnel exists on the PLR (penultimate router) but the primary tunnel is NOT using it. `show mpls traffic-eng fast-reroute database` shows the primary tunnel is "unprotected."

Fix the network so that the primary tunnel is FRR-protected and the backup tunnel is assigned.

Verify: `show mpls traffic-eng tunnels tunnel2` shows "FRR enabled" and "backup assigned." `show mpls traffic-eng fast-reroute database` shows the tunnel as protected.

Score: 2 Points

---

## Ticket 10

FRR (Ticket 9 resolved): The backup tunnel exists and is assigned, but when the protected link is shut down, traffic does NOT reroute to the backup within 50ms. Instead, the headend recomputes a new path (taking 2-3 seconds).

Fix the network so that FRR local repair happens at the PLR within 50ms of link failure.

Verify: Shut the protected link — traffic reroutes immediately via the backup tunnel. `show mpls traffic-eng fast-reroute database` shows "Active" state during the failure.

Score: 2 Points

---

## Ticket 11

TE tunnel path-protection (1:1): Tunnel1 has a primary explicit path and a secondary (standby) path. The secondary path will NOT pre-signal. It remains in "path option standby" but never establishes an LSP to be ready for failover.

Fix the network so that the secondary path is pre-signaled and ready for immediate switchover.

Verify: `show mpls traffic-eng tunnels tunnel1` shows both primary and secondary paths signaled. Failover happens in <100ms when primary path fails.

Score: 3 Points

---

## Ticket 12

Multiple TE tunnels are contending for bandwidth on the same link. Priority/preemption should resolve this — higher-priority tunnels should preempt lower ones. However, a low-priority tunnel (setup=7, hold=7) is NOT being preempted by a high-priority tunnel (setup=1, hold=1).

Fix the network so that TE preemption works correctly and the high-priority tunnel gets bandwidth.

Verify: The high-priority tunnel is UP with reserved bandwidth. The low-priority tunnel is rerouted to an alternate path or is DOWN. `show ip rsvp reservation` confirms correct priority allocation.

Score: 3 Points

---

## Ticket 13

PCEP (Path Computation Element Protocol): The headend (R1) is configured to delegate path computation to an external PCE (simulated). The PCEP session is Established but the PCE is returning a path with a strict hop that doesn't exist in the topology. The tunnel won't signal because the computed path is invalid.

Fix the network so that the PCE delegation produces a valid path OR the headend falls back to local CSPF.

Verify: Tunnel comes UP with a valid signaled path. `show mpls traffic-eng tunnels` shows either PCE-computed valid path or local CSPF path.

Score: 4 Points

---

## Ticket 14

Inter-area TE: Tunnel1 needs to cross an OSPF area boundary (R4 is an ABR into a stub area containing R9). The TE topology database on R1 does NOT contain links beyond the ABR. CSPF fails because it has incomplete topology information.

Fix the network so that the TE tunnel can be signaled across the area boundary to R9.

Verify: `show mpls traffic-eng tunnels tunnel1` shows state UP with path traversing the area boundary. `show mpls traffic-eng topology` shows topology information for both areas (or loose-hop signaling works).

Score: 4 Points

---

## Ticket 15

Shared Risk Link Group (SRLG): Two physically diverse tunnels (primary and backup) are supposed to use disjoint paths. However, both tunnels have been routed over the same physical fiber bundle (same SRLG). If that fiber cuts, BOTH tunnels fail.

Fix the network so that the backup tunnel avoids all SRLGs used by the primary tunnel.

Verify: `show mpls traffic-eng tunnels` — primary and backup have NO shared SRLG values. `show mpls traffic-eng link-management srlg` confirms SRLG exclusion.

Score: 4 Points

---

## Ticket 16

Make-before-break (MBB) reoptimization: Tunnel0 is UP on a suboptimal path because the optimal path was unavailable when it first signaled. The optimal path is now available, but the tunnel is NOT reoptimizing. Reoptimization timer has been configured and has expired multiple times.

Fix the network so that the tunnel reoptimizes to the better path using make-before-break.

Verify: `show mpls traffic-eng tunnels tunnel0` shows the optimal (shorter) path. `show mpls traffic-eng tunnels tunnel0 history` shows the reoptimization event.

Score: 4 Points

---

## Ticket 17

DS-TE (DiffServ-aware TE): Two class-types (CT0 = best-effort, CT1 = premium) are configured with bandwidth constraints (MAM model). A CT1 tunnel is being rejected because the CT1 bandwidth pool is exhausted, even though the CT0 pool has ample bandwidth. The CT1 tunnel should be able to borrow from CT0 under the configured model.

Fix the network so that the DS-TE bandwidth constraint model allows appropriate sharing and the CT1 tunnel signals.

Verify: `show mpls traffic-eng tunnels` — CT1 tunnel is UP. `show mpls traffic-eng link-management bandwidth-allocation` shows correct DS-TE pool allocation.

Score: 4 Points

---

## Ticket 18

Complete FRR failure: A link goes down and instead of fast local repair, ALL tunnels traversing that link go DOWN simultaneously. The PLR has backup tunnels configured and assigned. RSVP state is correct. The issue is in the forwarding plane — the LFIB is not switching to the backup path.

Fix the network so that FRR local repair works in the data plane (LFIB switchover within 50ms).

Verify: Shut the protected link — all affected tunnels remain UP via backup. `show mpls forwarding-table` on PLR shows backup label swap entries active. Traffic loss < 50ms.

Score: 5 Points

---

## Ticket 19

TE tunnel flapping: Tunnel3 is cycling UP/DOWN every 45-60 seconds. Each time it comes UP, RSVP PATH goes out, RESV comes back, LSP is established — then 45-60 seconds later the LSP is torn down. No link flaps, no IGP changes, no bandwidth contention.

Fix the network so that Tunnel3 remains stable and UP indefinitely.

Verify: `show mpls traffic-eng tunnels tunnel3` — uptime exceeds 5 minutes with no flaps. `show log` shows no tunnel state changes.

Score: 5 Points

---

## Ticket 20

Multi-tunnel failure scenario:
- Tunnel0 (dynamic): DOWN — CSPF finds no path despite all links visible
- Tunnel1 (explicit): DOWN — path exists but RSVP signaling rejected at midpoint
- Tunnel2 (FRR): UP but unprotected — backup assignment broken
- Tunnel3 (affinity): DOWN — affinity links exist but not visible in TE topology

Fix ALL four tunnels simultaneously.

Verify: All tunnels UP. Tunnel0 dynamic shortest path. Tunnel1 explicit through north path. Tunnel2 FRR-protected with backup assigned. Tunnel3 using gold-affinity links.

Score: 5 Points

---

## Scoring Summary

| Tickets | Difficulty | Points Each | Total |
|---|---|---|---|
| 1-3 | CCNP-SP (⭐⭐) | 2 | 6 |
| 4-6 | CCNP-SP (⭐⭐⭐) | 3 | 9 |
| 7-9 | CCNP-SP (⭐⭐⭐) | 2-3 | 7 |
| 10-12 | CCNP→CCIE (⭐⭐⭐) | 2-3 | 8 |
| 13-17 | CCIE-SP (⭐⭐⭐⭐) | 4 | 20 |
| 18-20 | CCIE-SP (⭐⭐⭐⭐⭐) | 5 | 15 |
| **Total** | | | **65 Points** |

**Passing:** 49/65 (75%)
**CCIE-ready:** 59/65 (90%)
