# OSPF — Study Notes

**SPCOR Chapter:** 6 — OSPF

*Notes to be added as you read the chapter and lab it. Key topics: multi-area, summarization, stub/NSSA, virtual links, OSPF-TE interaction, sham-link, DN-bit, convergence tuning.*

---

## Key Concepts from Labs

### OSPF + MPLS Conflict
- OSPF summarization breaks LDP label bindings (LDP needs /32 loopbacks). This is WHY SPs prefer IS-IS (flat L2, no summarization needed).

### Sham-Link
- Creates intra-area OSPF adjacency across MPLS VPN core
- Source/destination = VRF loopbacks advertised via BGP (not OSPF)
- Prevents backdoor link from being preferred over VPN path (intra-area vs inter-area)

### DN-Bit
- Set by PE when redistributing BGP VPN routes into OSPF
- Prevents another PE from re-redistributing back into BGP (loop prevention)

### LDP-IGP Sync
- Configure under `router ospf 1` → `mpls ldp sync`
- OSPF advertises max-metric on interface when LDP session is down
- Test by removing `mpls ip` on the REMOTE side (not local)

### Administrative Distances
- eBGP = 20, OSPF = 110, iBGP = 200
- With eBGP PE-CE: VPN path (AD 20) preferred over OSPF backdoor (AD 110)
- With OSPF PE-CE: backdoor (intra-area) preferred over VPN (inter-area) → sham-link needed
