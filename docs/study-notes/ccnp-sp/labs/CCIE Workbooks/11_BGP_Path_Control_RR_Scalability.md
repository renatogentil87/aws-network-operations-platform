# CCIE SP Workbook 11 — BGP Path Control & Route-Reflector Scalability

**Platform:** Cisco 7200, IOS 15.2 — local GNS3
🔴 **CCIE Prep Platform:** EVE-NG (IOS-XRv + CSR1000v) — see `00_EVENG_Topology.md` for the Emerald+Garnet topology — some features (Add-Path, PIC) are more fully supported on IOS-XR/EVE-NG; configure-and-document where the XRv falls short.
**Topology:** Two ASes (X + Y) per `gns3_base_topology.md`. RRs: X-PE1/PE2 (AS X), Y-P1/P2 (AS Y).
**Initial configs:** Workbook 04 complete — MP-BGP VPNv4 via RRs, multiple VRFs.

> **Note:** This workbook drills BGP best-path manipulation, scalable RR design, and fast convergence (Add-Path, Best-External, BGP PIC) — the control-plane resilience that makes multi-homed VPN services fail over in milliseconds.

---

## Section 1 — Best-Path Manipulation

### Task 1.1
- For a multi-homed customer prefix, force egress via PE-A using each attribute in turn and confirm which step decides: **Weight**, **Local-Preference**, **AS-Path prepend**, **MED**.
- Document the order and which step actually broke the tie each time.

**Configuration**

BGP best-path is a strict ordered list — Weight (local, highest) → Local-Pref (AS-wide) → locally-originated → AS-Path length → Origin → MED → **eBGP over iBGP** → IGP metric to next-hop → oldest eBGP → router-id → cluster-list → neighbor. The practitioner's mental model: **Weight/Local-Pref control outbound** (how *we* exit), **AS-Path/MED influence inbound** (how *others* reach us); everything below is a tiebreaker. The skill is knowing *which* step your change acts on, and that a higher step (e.g., AS-Path) overrides the "prefer eBGP" step below it.

**Verification**
- `show ip bgp <prefix>` — the `best` marker moves as you change each attribute; read where it stopped tying.
- `show ip bgp <prefix>` MED shows on the attribute line; IGP metric shows as `(metric X)` next to the next-hop — distinguish the two.

---

## Section 2 — Communities & Scalable Policy

### Task 2.1
- Tag customer routes with **standard and extended communities** at ingress; use them to set Local-Preference on the far PE and to trigger **NO_EXPORT / NO_ADVERTISE** behavior.

**Configuration**

Communities decouple *marking* (at the edge) from *action* (elsewhere), so policy scales without per-prefix config network-wide: tag at ingress, act on the tag at the RR/egress. Well-known communities (NO_EXPORT, NO_ADVERTISE, LOCAL_AS) give instant scope control. This is how SPs implement customer/peer/transit route policies consistently across hundreds of routers.

**Verification**
- `show ip bgp <prefix>` — communities attached; `send-community both` in effect.
- Far PE applies Local-Pref based on the community; NO_EXPORT prefixes stay within the AS.

---

## Section 3 — RR Path Diversity: Add-Path & Best-External

### Task 3.1
- Demonstrate **RR path hiding**: a multi-homed prefix where the RR reflects only its single best path, so a client never sees the backup.
- Fix it with **BGP Add-Path** (advertise best + additional paths) and separately with **unique RD per PE**; contrast the two.

**Configuration**

An RR runs best-path and reflects only ONE path per NLRI — so downstream PEs can't fail over to a hidden backup. Two fixes: **Add-Path** (RFC 7911) tags multiple paths with path-IDs so the RR advertises several per prefix; **unique RD per PE** makes each PE's advertisement a distinct VPNv4 NLRI so the RR can't collapse them (change RD, keep RT). Add-Path is general (works for the global table too); unique-RD is the clean VPN answer. Both restore the path diversity that fast failover (PIC) depends on.

### Task 3.2
- Configure **Best-External** on a PE whose best path is iBGP so it still advertises its best *external* path to the RRs.

**Configuration**

When a PE's iBGP path wins best-path (e.g., a higher-priority attribute like a prepend on its own eBGP path pushed the external path to non-best), it normally advertises nothing external — hiding a valid exit. **Best-External** makes it advertise its best external path anyway, feeding the alternate exit into the RR system for fast reconvergence. Remember: eBGP-over-iBGP is only step 7, so an iBGP path can win at an earlier step (Local-Pref/AS-Path/MED) — that's exactly when Best-External earns its keep.

**Verification**
- Before: `show ip bgp <prefix>` on the client shows ONE path.
- After Add-Path / unique-RD: the client shows **two** paths; Best-External shows the `x best-external` flag.

---

## Section 4 — BGP PIC & Hierarchical RRs

### Task 4.1
- Enable **BGP PIC** (Prefix-Independent Convergence) — install a pre-computed backup next-hop so failover is one FIB operation regardless of prefix count.
- Fail a next-hop with continuous traffic; show convergence independent of table size.

**Configuration**

Without PIC, a next-hop failure forces per-prefix best-path recompute — minutes at scale. **PIC** uses a **hierarchical FIB with indirection**: prefixes point at a shared next-hop object holding primary + pre-installed backup, so on failure you flip ONE object and all prefixes follow — sub-second, prefix-independent. PIC needs a backup path to *exist and be visible* (Section 3's Add-Path/unique-RD/Best-External), so they form a chain: make the backup visible → PIC pre-installs it → instant failover. PIC-Core protects the path to the next-hop (with LFA/TI-LFA); PIC-Edge protects the egress PE via a backup BGP next-hop.

### Task 4.2
- Build a **two-level hierarchical RR** design (regional RRs as clients of core RRs), using consistent cluster-ids for redundancy; enable **RT-Constrain** to limit VPNv4 distribution.

**Configuration**

Flat RR designs still push every route to every client. **Hierarchical RRs** partition the mesh: regional RRs serve local PEs and are clients of core RRs, so session/route counts grow linearly, not quadratically. Redundant RRs in a cluster share a **cluster-id** so clients see identical CLUSTER_LISTs and don't treat them as different paths. **RT-Constrain (RFC 4684)** stops an RR sending a PE VPNv4 routes it doesn't import — the biggest scale win on large multi-VRF cores.

**Verification**
- `show cef <prefix> detail` — primary + backup next-hop installed (PIC); fail the next-hop and confirm sub-second, table-size-independent convergence.
- `show bgp vpnv4 all rt-filter` — RT-Constrain filtering active; a PE stops receiving RTs it doesn't import.

---

## CCIE Challenge Tasks

### Challenge A — Optimal RR placement / suboptimal-routing fix
- Reproduce RR-induced suboptimal routing (RR picks best on *its* IGP metric, not the client's), then fix with Add-Path or additional RR placement. Explain the mechanism.

### Challenge B — Full fast-convergence stack
- Combine **TI-LFA (IGP) + Add-Path/unique-RD (visibility) + BGP PIC (edge)** and prove end-to-end sub-second failover for a multi-homed VPN prefix on both a core-link and an egress-PE failure.

### Challenge C — Confederations vs RRs
- Rebuild a slice using **BGP confederations** instead of RRs; contrast attribute handling, scalability, and when each is the right choice.
