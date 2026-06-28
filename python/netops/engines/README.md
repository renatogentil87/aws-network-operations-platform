# Core Engines

Here you create the core business logic engines that power the CLI.

## Files to Create

- `inventory_engine.py` — Discovers VPCs, TGWs, VPNs, routes across accounts
- `validation_engine.py` — Checks route symmetry, blackhole routes, SG rules, NACLs
- `testing_engine.py` — Connectivity tests, path validation, GNS3 BGP route checks
- `drift_engine.py` — Compares Terraform state vs live AWS, detects config drift
- `recovery_engine.py` — Auto-remediation: restart VPN tunnels, fix routes, failover
- `chaos_engine.py` — Inject failures: kill VPN tunnels, blackhole routes, simulate AZ failure
- `scoring_engine.py` — Operational maturity score based on checks passed/failed

## Design Notes

- Engines are stateless classes instantiated by commands
- Each engine receives an AWS session and config object
- Engines return structured results (dataclasses or dicts)
- Commands handle presentation; engines handle logic
