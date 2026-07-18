# Study Plan — Principal Cloud Network Architect

**Start Date:** 2026-07-13
**Pace:** 6-10 hours/week
**Philosophy:** Read → Note → Lab → Automate → Publish → Move On

---

## Note-Taking Strategy

**Method: Hybrid (Book marks + Digital notes)**

| Where | What | Why |
|-------|------|-----|
| **Book (physical/PDF highlights)** | Key concepts, formulas, diagrams, "aha" moments | Fast to mark while reading, builds spatial memory |
| **Digital notes (one .md per book)** | Summarized concepts in YOUR words, lab prep questions, commands to try | Forces you to reprocess — if you can't explain it without the book, you don't know it |
| **Lab journal (one .md per lab)** | What you configured, what broke, what you learned, configs that worked | This is what you'll reference 6 months later, not the book |

**The rule:** After finishing a chapter group, write a 1-page summary from memory BEFORE opening your highlights. The gaps reveal what you didn't actually absorb. Then fill them in.

**File structure:**
```
/Users/rrdog/Desktop/aws-network-operations-platform/docs/study-notes/
├── book-01-mpls-fundamentals/
│   ├── chapters-01-04-label-switching.md
│   ├── chapters-05-07-ldp-and-mpbgp.md
│   ├── chapters-08-11-vpn-and-te.md
│   └── labs/
│       ├── lab-01-mpls-forwarding.md
│       ├── lab-02-l3vpn.md
│       └── lab-03-traffic-engineering.md
├── book-02-bgp-design/
│   ├── chapters-01-04-bgp-fundamentals.md
│   ├── chapters-05-08-design-patterns.md
│   ├── chapters-09-12-traffic-engineering.md
│   └── labs/
│       ├── lab-01-ebgp-multihoming.md
│       └── ...
└── ...
```

---

## Books & Chapter-to-Lab Mapping

### Book 1: MPLS Fundamentals (Luc De Ghein) — Jul–Aug 2026

| Chapters | Topics | Lab Trigger | Lab to Do |
|----------|--------|-------------|-----------|
| Ch 1 | Evolution of MPLS — history, motivation, overview | — | No lab (context only) |
| Ch 2–4 (+6) | MPLS architecture, forwarding labeled packets, LDP, CEF | After Ch 4 | **Lab 1: MPLS Forwarding Basics** — LDP adjacency, label allocation, push/swap/pop, PHP, `traceroute mpls` |
| Ch 5 | MPLS and ATM | — | Skip — legacy, not relevant to modern networks |
| Ch 7 | MPLS VPN (L3VPN) — the most important chapter | After Ch 7 | **Lab 2: MPLS L3VPN** — VRF, RD, RT import/export, PE-CE with BGP & OSPF, MP-BGP VPNv4 |
| Ch 8 | MPLS Traffic Engineering — RSVP-TE, constraint-based routing | After Ch 8 | **Lab 3: MPLS Traffic Engineering** — RSVP-TE tunnels, explicit paths, FRR, bandwidth reservation |
| Ch 9 | IPv6 over MPLS (6PE/6VPE) | — | No lab (read for awareness) |
| Ch 10–11 | AToM + VPLS — Layer 2 services over MPLS | After Ch 11 | **Lab 4: L2VPN (AToM + VPLS)** — Pseudowires, xconnect, VPLS full-mesh, MAC learning |
| Ch 12–14 | QoS, Troubleshooting, OAM | After Ch 14 | **Lab 5: MPLS QoS + OAM** — EXP bits, LSP ping/traceroute, MPLS OAM tools |
| Ch 15 | Future of MPLS | — | Skim only — cross-reference with Book 3 (Segment Routing) |

**Lab environment:** EVE-NG (c5.metal) — Cisco vIOS Router images
**Note:** Chapter 5 (ATM) and Chapter 15 (Future) are skippable. The meat is chapters 2-4, 7, and 8.

---

### Book 2: BGP Design and Implementation (Randy Zhang) — Aug–Sep 2026

| Chapters | Topics | Lab Trigger | Lab to Do |
|----------|--------|-------------|-----------|
| Ch 1–4 | BGP fundamentals, neighbor relationships, path selection, attributes | After Ch 4 | **Lab 1: eBGP Multi-homing** — Dual ISP, default routes, local-pref, weight, AS-PATH manipulation |
| Ch 5–6 | iBGP scaling, Route Reflectors, confederations | After Ch 6 | **Lab 2: iBGP + Route Reflectors** — Full mesh vs RR, cluster-id, RR hierarchies, `show ip bgp` path analysis |
| Ch 7–8 | BGP communities, extended communities, traffic engineering at scale | After Ch 8 | **Lab 3: BGP Communities for TE** — Standard/extended/large communities, local-pref via community, customer-triggered MED |
| Ch 9–10 | Prefix filtering, security, bogon filtering, RPKI concepts | After Ch 10 | **Lab 4: BGP Prefix Filtering** — Prefix lists, route maps, AS-PATH ACLs, ORF, max-prefix limits |
| Ch 11–12 | Convergence, BFD, graceful restart, advanced design patterns | After Ch 12 | **Lab 5: BGP Failover + BFD** — Sub-second detection, graceful restart, `show bfd neighbors` |
| Ongoing | AWS integration | Any time | **Lab 6: BGP to AWS** — Site-to-Site VPN with BGP, TGW route propagation, AS-PATH prepend for failover |

**Lab environment:** EVE-NG + AWS (real VPN tunnel to your TGW in eu-west-1)
**Note:** Lab 6 ties back to your Terraform platform — use the VPN module to create the tunnel, EVE-NG router as the CGW.

---

### Book 3: MPLS in the SDN Era (Antonio Sanchez-Monge) — Sep–Oct 2026

| Chapters | Topics | Lab Trigger | Lab to Do |
|----------|--------|-------------|-----------|
| Ch 1–5 | MPLS refresher in context of SDN, LDP/RSVP revisited, modern use cases | After Ch 5 | **Lab 1: Segment Routing MPLS** — SRGB, node SIDs, adjacency SIDs, SR-MPLS forwarding |
| Ch 6–9 | Segment Routing architecture, TI-LFA, SR-TE | After Ch 9 | **Lab 2: SR Traffic Engineering** — SR-TE policies, explicit paths via SID lists, TI-LFA protection |
| Ch 10–12 | SR in service provider, migration from LDP to SR, SR-MPLS + BGP | After Ch 12 | **Lab 3: LDP to SR Migration** — Dual-stack (LDP + SR), mapping server, graceful migration |

**Lab environment:** EVE-NG — Cisco IOS-XR or XE images with SR support (check if vIOS supports SR or need CSR1000v)

---

### Book 4: Building Data Centers with VXLAN BGP EVPN (Lukas Krattiger) — Oct–Nov 2026

| Chapters | Topics | Lab Trigger | Lab to Do |
|----------|--------|-------------|-----------|
| Ch 1–4 | Spine-leaf architecture, VXLAN fundamentals, underlay design | After Ch 4 | **Lab 1: VXLAN Fabric** — 2 spine + 4 leaf, eBGP underlay, VXLAN encap, VTEPs, `show nve peers` |
| Ch 5–7 | EVPN control plane, Route Types 2 & 3, ARP suppression | After Ch 7 | **Lab 2: EVPN Type-2** — MAC/IP learning, BUM handling, ARP suppression, `show bgp l2vpn evpn` |
| Ch 8–10 | EVPN Type-5, inter-VXLAN routing, symmetric IRB | After Ch 10 | **Lab 3: EVPN Type-5 + IRB** — IP prefix routing, symmetric vs asymmetric, distributed anycast GW |
| Ch 11–13 | Multi-tenancy, VRFs over VXLAN, DCI | After Ch 13 | **Lab 4: Multi-tenancy + DCI** — VRF with RT import/export over VXLAN, stretch fabric between sites |

**Lab environment:** EVE-NG — **Arista vEOS** (free download from arista.com — register for account)
**Note:** EVPN labs require vEOS or NX-OS. vIOS doesn't support EVPN. Download Arista vEOS before starting Book 4.

---

### Book 5: ENCOR 350-401 — Ongoing reference (no sequential labs)

Use as reference during other labs. Key chapters for quick lookup:
- QoS (queuing, shaping, policing) — reference during TE labs
- SDA (campus fabric) — compare with DC EVPN/VXLAN
- Security (MACsec, 802.1X) — reference during automation labs

---

### Book 6: ENAUTO 300-435 — Nov–Dec 2026

| Chapters | Topics | Lab Trigger | Lab to Do |
|----------|--------|-------------|-----------|
| Ch 1–4 | YANG models, NETCONF, device programmability | After Ch 4 | **Lab 1: NETCONF + YANG** — ncclient, get-config, edit-config, IOS-XE YANG models |
| Ch 5–7 | RESTCONF, REST APIs for network devices | After Ch 7 | **Lab 2: RESTCONF** — CRUD ops on IOS-XE, JSON/XML, Postman + Python requests |
| Ch 8–10 | Ansible for networking, roles, playbooks | After Ch 10 | **Lab 3: Ansible Network Roles** — ios_config, ios_command, Jinja2 templates, idempotency |
| Ch 11–13 | Python automation, Nornir, concurrent tasks | After Ch 13 | **Lab 4: Python + Nornir** — Inventory, tasks, structured output, concurrent execution |
| Ch 14–15 | CI/CD, testing, validation | After Ch 15 | **Lab 5: CI/CD for Network Config** — Git push → lint → validate → deploy → verify |

**Lab environment:** EVE-NG (IOS-XE CSR1000v for RESTCONF/NETCONF) + your Python repo (`/Users/rrdog/Desktop/aws-network-operations-platform/python/`)

---

### Book 7: SD-WAN Architecture and Design (Jason Gooley) — Dec 2026

| Chapters | Topics | Lab Trigger | Lab to Do |
|----------|--------|-------------|-----------|
| Ch 1–4 | SD-WAN architecture, controller model, OMP, underlay/overlay | After Ch 4 | **Lab 1: SD-WAN Architecture** — vManage, vSmart, vBond, vEdge/cEdge, OMP routes |
| Ch 5–7 | Policies, segmentation, app-aware routing | After Ch 7 | **Lab 2: SD-WAN Policy + Segmentation** — VPN segmentation, SLA classes, app-aware routing |
| Ch 8–10 | Cloud integration, DIA, cloud onramp | After Ch 10 | **Lab 3: SD-WAN + Cloud** — Cloud onramp for IaaS, DX/VPN coexistence |

**Lab environment:** EVE-NG — Cisco SD-WAN images (vManage, vSmart, vBond, cEdge) — requires Cisco VIRL/CML license or lab images

---

## AWS Hybrid Labs (Ongoing — Tied to Platform Build)

These labs use your Terraform platform directly. Do them as you build each phase:

| Lab | Tied to Platform Phase | Concepts |
|-----|----------------------|----------|
| TGW multi-account with centralized inspection | Phase 2 (next) | Firewall VPC, appliance mode, split routing |
| Cloud WAN with advanced routing policies | Phase 3+ | Segments, sharing, summarization, local-pref |
| Direct Connect traffic engineering | Platform + Book 2 Lab 6 | DXGW, Transit VIF, BGP communities, failover |
| VPN failover with BGP | Platform + Book 2 Lab 5 | AS-PATH prepend, BFD, convergence timing |
| Hybrid DNS (Route 53 Resolver) | Phase 4+ | Conditional forwarding, on-prem zone resolution |
| Network observability | Phase 3 | VPC Flow Logs, CloudWatch metrics, alerting |

---

## Monthly Targets (Updated)

| Month | Read | Lab After Reading | Platform Build | Output |
|-------|------|-------------------|----------------|--------|
| Jul | MPLS Ch 1–7 | Labs 1-2 (forwarding + L3VPN) | Phase 2: Inspection VPC + NFW | Book chapters 9-10 |
| Aug | MPLS Ch 8–11 + BGP Ch 1–6 | MPLS Labs 3-4 + BGP Labs 1-2 | Phase 3: Observability | Book chapters 11-12 |
| Sep | BGP Ch 7–12 + MPLS SDN Ch 1–5 | BGP Labs 3-5 + SR Lab 1 | Phase 4: Python CLI | Book chapters 13-14 |
| Oct | MPLS SDN Ch 6–12 + EVPN Ch 1–7 | SR Labs 2-3 + EVPN Labs 1-2 | Phase 5: Inventory Engine | Book chapters 15-16 |
| Nov | EVPN Ch 8–13 + ENAUTO Ch 1–10 | EVPN Labs 3-4 + Auto Labs 1-3 | Phase 6: Validation | Book chapters 17-20 + ENCOR exam |
| Dec | ENAUTO Ch 11–15 + SD-WAN | Auto Labs 4-5 + SD-WAN Labs | Phase 7: Testing | ENAUTO exam |

---

## EVE-NG Lab Environment

- **Instance:** c5.metal (Eveng AWS account — 372468809129)
- **Images available:** Cisco vIOS Router, Cisco vIOS L2, FortiGate VM
- **Needed:** Arista vEOS (free — arista.com, for EVPN/VXLAN labs in Oct)
- **Needed:** CSR1000v or IOS-XR (for SR and NETCONF/RESTCONF labs)
- **Needed:** SD-WAN images (vManage, vSmart, cEdge — Dec)
- **⚠️ Stop instance when not in use (~$4/hr). IOL doesn't work on AWS kernel — use QEMU only.**

---

## Progress Tracker

| Book | Chapters Read | Notes Written | Labs Completed |
|------|--------------|---------------|----------------|
| 1. MPLS Fundamentals | /11 | /3 groups | /4 labs |
| 2. BGP Design | /12 | /3 groups | /6 labs |
| 3. MPLS SDN Era | /12 | /3 groups | /3 labs |
| 4. EVPN/VXLAN | /13 | /3 groups | /4 labs |
| 5. ENCOR | — | — | Reference only |
| 6. ENAUTO | /15 | /3 groups | /5 labs |
| 7. SD-WAN | /10 | /3 groups | /3 labs |
