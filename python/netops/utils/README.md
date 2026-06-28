# Shared Utilities

Here you create shared utility modules used across the CLI.

## Files to Create

- `aws_session.py` — Multi-account assume-role helper (STS session factory)
- `config.py` — Load and validate YAML config files
- `logger.py` — Structured logging setup (JSON format)
- `gns3_client.py` — API client for GNS3 server to query BGP routes from simulated routers

## Design Notes

- `aws_session.py` handles cross-account credential chaining
- `config.py` reads from `configs/` directory (accounts, networks, thresholds)
- `gns3_client.py` communicates with GNS3 REST API to verify BGP state
- All utilities are importable by engines and commands
