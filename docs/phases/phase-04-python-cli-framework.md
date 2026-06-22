# Phase 4: Python CLI Framework

## Objective

Build the `netops` CLI skeleton — a Python application that serves as the operational interface for all network operations tasks (inventory, validation, testing, drift, recovery, reporting, scoring, chaos).

## Deliverables

1. **CLI framework** — Click or Typer-based CLI with subcommands
2. **Plugin architecture** — Each command is a pluggable module (easy to extend)
3. **AWS session management** — Multi-account credential handling (assume role, SSO, profiles)
4. **Configuration system** — YAML-based config for regions, accounts, thresholds
5. **Output formatting** — Table, JSON, and CSV output modes
6. **Logging & verbosity** — Structured logging with debug/info/warning levels
7. **Package structure** — pip-installable package with entry point

## Detailed Implementation

### 1. CLI Command Structure

```
netops
├── inventory    # Discover and catalog network resources
├── validate     # Check configurations against policies
├── test         # Run connectivity and path tests
├── drift        # Compare live state vs. expected state
├── recover      # Execute automated remediation
├── report       # Generate reports (HTML, PDF, JSON)
├── score        # Calculate operational maturity score
└── chaos        # Inject controlled failures
```

### 2. Package Layout

```
python/
├── pyproject.toml           # Project metadata, dependencies, entry points
├── netops/
│   ├── __init__.py
│   ├── cli.py               # Main CLI entry point
│   ├── config.py            # Configuration loader
│   ├── session.py           # AWS session/credential management
│   ├── output.py            # Output formatters (table, json, csv)
│   ├── commands/
│   │   ├── __init__.py
│   │   ├── inventory.py
│   │   ├── validate.py
│   │   ├── test.py
│   │   ├── drift.py
│   │   ├── recover.py
│   │   ├── report.py
│   │   ├── score.py
│   │   └── chaos.py
│   ├── engines/
│   │   ├── __init__.py
│   │   ├── inventory_engine.py
│   │   ├── validation_engine.py
│   │   ├── test_engine.py
│   │   ├── drift_engine.py
│   │   ├── recovery_engine.py
│   │   ├── report_engine.py
│   │   ├── scoring_engine.py
│   │   └── chaos_engine.py
│   └── utils/
│       ├── __init__.py
│       ├── aws.py           # AWS API helpers
│       ├── cache.py         # Local caching
│       └── parallel.py      # Concurrent execution helpers
└── tests/
    ├── conftest.py
    ├── test_inventory.py
    ├── test_validate.py
    └── ...
```

### 3. AWS Session Management

- Support multiple authentication methods: profiles, SSO, assume-role chain
- Multi-account execution: iterate over configured accounts, assume role in each
- Region iteration: run commands across configured regions in parallel
- Session caching: reuse credentials within their validity window

### 4. Configuration File (`netops.yaml`)

```yaml
platform:
  name: "ANOP"
  primary_region: "ca-central-1"
  dr_region: "us-east-1"

accounts:
  network-hub:
    id: "111111111111"
    role: "NetOpsReadOnlyRole"
  prod:
    id: "222222222222"
    role: "NetOpsReadOnlyRole"
  non-prod:
    id: "333333333333"
    role: "NetOpsReadOnlyRole"

regions:
  - ca-central-1
  - us-east-1

thresholds:
  drift:
    critical: 0    # Zero tolerance for drift in prod
    warning: 5
  health:
    packet_drop_rate: 0.01
    tunnel_uptime: 99.9
```

### 5. Output Modes

All commands support `--output` flag:
- `table` (default) — Rich-formatted terminal table
- `json` — Machine-readable JSON
- `csv` — For spreadsheet consumption
- `html` — For report generation (Phase 12)

### 6. Core Dependencies

- `typer` or `click` — CLI framework
- `boto3` — AWS SDK
- `rich` — Terminal formatting (tables, progress bars)
- `pyyaml` — Configuration parsing
- `pydantic` — Data validation and models
- `concurrent.futures` — Parallel execution

## Acceptance Criteria

- [ ] `pip install -e .` installs the package with `netops` entry point
- [ ] `netops --help` shows all subcommands
- [ ] `netops inventory --help` shows inventory-specific options
- [ ] `netops` can assume roles across multiple accounts
- [ ] Output renders correctly in table, json, and csv modes
- [ ] `pytest` passes with >80% coverage on framework utilities
- [ ] Configuration file loads and validates without errors

## Dependencies

- Phase 0 complete (repo structure, CI/CD for Python)
- AWS accounts accessible with read-only roles

## Estimated Effort

3–4 days
