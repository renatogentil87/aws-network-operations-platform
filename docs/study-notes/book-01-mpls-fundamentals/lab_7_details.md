# Lab 7: Advanced MPLS TE — Workbook

**Platform:** GNS3 Local (Cisco 7200)
**Prerequisite:** Lab 3 complete (basic TE tunnels, explicit paths, failover working)

---

## Task 1: Fast Reroute (FRR) — Link Protection

1. On Tunnel0 (R2→R8): enable FRR: `tunnel mpls traffic-eng fast-reroute`
2. On R3 (transit router in the primary path): create a backup tunnel
   - Backup tunnel goes around the protected link (e.g., R3→R6→R7 to bypass R3→R4 link)
   - `interface Tunnel10` → small bandwidth, explicit path avoiding the protected link
3. On R3's interface toward R4: `mpls traffic-eng backup-path Tunnel10`
4. Verify: `show mpls traffic-eng fast-reroute database` — backup is pre-computed
5. Start continuous ping from R1 to R9 (1000 packets)
6. Shut R3's link toward R4
7. Count dropped packets — should be 0 or 1 (sub-50ms switchover)
8. Compare with Task 4 of Lab 3 (path-option failover) — FRR should be much faster
9. Bring link back — verify primary path restores

---

## Task 2: Node Protection (Next-Next-Hop Backup)

1. Instead of protecting just the link R3→R4, protect against R4 failing entirely
2. On R3: create a backup tunnel that bypasses R4 completely (goes R3→R7→R5 or similar)
3. Configure as NNHOP (next-next-hop) backup
4. Verify: `show mpls traffic-eng fast-reroute database` shows NNHOP protection
5. Shut ALL interfaces on R4 (simulate node failure)
6. Verify: traffic continues flowing via the NNHOP backup
7. Count packet loss — should still be minimal

---

## Task 3: Affinity Bits — Avoid Satellite Links

**Scenario:** Pretend FastEthernet links are "satellite" (high latency) and GigabitEthernet are "terrestrial" (low latency).

1. On all FastEthernet interfaces in the core: `mpls traffic-eng attribute-flags 0x1`
2. On all GigabitEthernet interfaces: `mpls traffic-eng attribute-flags 0x2`
3. Create Tunnel_Terrestrial: affinity 0x2 mask 0x2 (MUST use GigE links only)
4. Create Tunnel_Any: affinity 0x0 mask 0x0 (can use any link)
5. Verify: Tunnel_Terrestrial avoids all FastEthernet links
6. Verify: `show mpls traffic-eng tunnels tun_X` — explicit route shows only GigE hops
7. Shut all GigE links from R2 — Tunnel_Terrestrial should go DOWN (no valid path)
8. Tunnel_Any should still be up (can use FastEthernet)

---

## Task 4: Affinity Bits — Prefer Low-Cost Links

1. Mark some links as "premium" (0x4) and others as "economy" (0x8)
2. Create a tunnel for premium traffic: affinity 0x4 mask 0x4
3. Create a tunnel for economy traffic: affinity 0x8 mask 0x8
4. Verify: each tunnel uses only its designated links
5. Use case: different SLA tiers for different customers over same core

---

## Task 5: Preemption — SLA Tiers

1. Create Tunnel_Gold on R2 → R8: priority 0 0, bandwidth 80000
2. Create Tunnel_Silver on R2 → R8: priority 4 4, bandwidth 80000
3. Create Tunnel_Bronze on R2 → R8: priority 7 7, bandwidth 80000
4. All three use the same path (same explicit path or dynamic)
5. If the path only has 100000 available: which tunnels come up? Which fail?
6. Verify: Gold preempts Silver, Silver preempts Bronze
7. Remove Tunnel_Gold — does Tunnel_Silver recover?
8. Remove Tunnel_Silver — does Tunnel_Bronze recover?
9. Verify: `show ip rsvp reservation` — observe who holds reservations at each step

---

## Task 6: Auto-Bandwidth

1. Configure auto-bandwidth on Tunnel0:
   - `tunnel mpls traffic-eng auto-bw`
   - Max: 500000, Min: 1000
   - Collection interval: 1 minute (for lab speed)
   - Adjustment threshold: 10%
2. Verify initial bandwidth reservation (should be minimum or last known)
3. Generate traffic: `ping 9.9.9.9 repeat 10000 size 1500` from R1
4. Wait for collection interval to pass
5. Check: `show mpls traffic-eng tunnels tun0 | include auto-bw`
6. Verify: bandwidth reservation increased
7. Stop the traffic, wait again
8. Verify: bandwidth reservation decreases back toward minimum

---

## Task 7: Load Sharing Between TE Tunnels

1. Create two tunnels from R2 to R8 with DIFFERENT explicit paths
2. Both tunnels have `autoroute announce` enabled
3. Both tunnels have the same bandwidth
4. Verify: `show ip cef 8.8.8.8 internal` — both tunnels appear in hash buckets
5. From R1, traceroute to different R9 destinations — observe traffic split across tunnels
6. Change one tunnel's `loadshare` value — verify distribution changes
7. Verify: `show mpls traffic-eng autoroute` — shows both tunnels participating

---

## Task 8: TE Administrative Weight

1. On the link R3→R7 (GigE, currently TE metric 10): set `mpls traffic-eng administrative-weight 5000`
2. Leave the IGP metric unchanged (still 10)
3. Create a dynamic tunnel from R2 to R8
4. Verify: dynamic tunnel AVOIDS the R3→R7 link (TE weight too high)
5. Do a normal traceroute from R2 to R8 (no tunnel) — verify IGP still uses R3→R7
6. Proves: TE decisions and IGP decisions are independent

---

## Task 9: Tunnel Reoptimization Timer

1. Set reoptimization timer: `mpls traffic-eng reoptimize timers frequency 60` (1 minute)
2. Force Tunnel0 onto backup path (shut a link in primary)
3. Bring the link back
4. Wait — tunnel should reoptimize back to primary within 60 seconds automatically
5. Verify: no manual intervention needed
6. Compare with default timer (3600 seconds / 1 hour)

---

## Task 10: Inter-Area TE (Stretch Goal)

1. Split your OSPF core into two areas (Area 0 and Area 1)
2. R3 becomes an ABR between areas
3. Attempt to build a TE tunnel that crosses areas
4. Observe: does it work? (Hint: standard RSVP-TE is single-area)
5. Research: how would inter-area TE work? (loose hops, ABR as midpoint)
6. Configure with loose hop: `next-address loose 8.8.8.8`

---

## Validation Checklist

- [ ] FRR: 0-1 packets lost during link failure (vs 2-3 with path-option failover)
- [ ] Node protection: traffic survives complete router failure
- [ ] Affinity: tunnels respect colour constraints
- [ ] Preemption: high priority kicks out low priority
- [ ] Auto-bandwidth: reservation adapts to traffic load
- [ ] Load sharing: CEF distributes across multiple tunnels
- [ ] Admin weight: TE and IGP path selection operate independently
- [ ] Reoptimization timer: automatic return to primary path
