# Operational Runbooks

Here you create step-by-step runbooks for network incident response.

## Files to Create

- `vpn-tunnel-down.md` — Diagnose and restore VPN tunnel connectivity
- `bgp-flap-response.md` — Investigate and stabilize BGP flapping
- `az-failover.md` — Procedure for AZ failure (reroute traffic)
- `dr-failover.md` — Disaster recovery region failover procedure
- `route-leak-remediation.md` — Detect and fix route leaks between segments

## Design Notes

- Each runbook follows: Detect → Diagnose → Remediate → Verify → Post-mortem
- Automated steps reference `netops` CLI commands
- Manual steps include AWS Console paths as fallback
- Runbooks linked from CloudWatch alarm descriptions
