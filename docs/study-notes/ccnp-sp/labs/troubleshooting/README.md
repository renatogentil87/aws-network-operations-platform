# Troubleshooting Labs

Each troubleshooting lab corresponds to a configuration lab and contains 10+ scenarios to diagnose and fix.

**How it works:**
1. You build the GNS3 topology (same 20-router topology as configuration labs)
2. You tell the AI which troubleshooting lab you want
3. The AI connects to your routers via telnet and configures the base + broken state
4. You receive ONLY the symptoms — then troubleshoot blind
5. You fix the issue and verify

**Platform:** GNS3 Local — same 20-router topology (Cisco 7200, IOS 15.2)

---

## Troubleshooting Labs (To Be Created After Each Config Lab Is Complete)

| TS Lab | Matches Config Lab | Topics | Status |
|---|---|---|---|
| ts_lab_1.md | Lab 1 (MPLS Basics) | OSPF adjacency, LDP sessions, label allocation, PHP, LFIB | ⬜ |
| ts_lab_2.md | Lab 2 (L3VPN) | VRF, RT/RD, vpnv4 reflection, PE-CE protocols, as-override, RR | ⬜ |
| ts_lab_3.md | Lab 3 (MPLS TE) | Tunnel UP/DOWN, CSPF, bandwidth, affinity, autoroute, FRR | ⬜ |
| ts_lab_4.md | Lab 4 (AToM) | Pseudowire UP/DOWN, VC labels, targeted LDP, AC status | ⬜ |
| ts_lab_5.md | Lab 5 (AToM + TE) | PW preferred-path, fallback, redundancy, VLAN interworking | ⬜ |
| ts_lab_6.md | Lab 6 (Advanced L3VPN) | Shared services RT, hub-spoke, SOO, extranet, import-map | ⬜ |
| ts_lab_7.md | Lab 7 (OAM & Protection) | LSP ping failures, BFD, LFA, LDP sync, graceful restart | ⬜ |
| ts_lab_8.md | Lab 8 (BGP Policy) | Path selection, communities, max-prefix, RT-constraint | ⬜ |
| ts_lab_9.md | Lab 9 (Python Automation) | Script failures, connectivity, parsing errors | ⬜ |
| ts_lab_10.md | Lab 10 (IS-IS) | Adjacency, levels, route leaking, authentication, overload | ⬜ |
| ts_lab_11.md | Lab 11 (VPLS) | VFI, MAC learning, split-horizon, BUM flooding | ⬜ |
| ts_lab_12.md | Lab 12 (6PE/6VPE) | vpnv6, send-label, IPv6 VRF, address-family activation | ⬜ |
| ts_lab_13.md | Lab 13 (mVPN) | MDT, PIM VRF, core multicast, IGMP, data MDT | ⬜ |
| ts_lab_14.md | Lab 14 (Security) | CoPP blocking legitimate traffic, uRPF drops, ACL issues | ⬜ |
| ts_lab_15.md | Lab 15 (QoS) | Wrong class, EXP mapping, policing drops, queuing config | ⬜ |

---

## Workflow Per Troubleshooting Session

```
You: "Give me ts_lab_2 scenario 3"
AI:  Connects to routers → configures base + break → "Ready. Symptoms: R1 cannot ping R9..."
You: Troubleshoot using show commands
You: Fix the issue
You: "Done — verify"
AI:  Confirms fix or tells you what's still broken
```
