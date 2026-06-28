# CLI Commands

Here you create Click CLI command modules for the netops tool.

## Files to Create

- `__init__.py` — Register all command groups with the main CLI
- `inventory.py` — Discover and list all network resources
- `validate.py` — Run validation checks against live infrastructure
- `test.py` — Execute connectivity and path tests
- `drift.py` — Detect configuration drift (Terraform state vs live)
- `recover.py` — Auto-remediate common network failures
- `report.py` — Generate network health reports
- `score.py` — Calculate operational maturity score
- `chaos.py` — Inject controlled failures for resilience testing

## Design Notes

- Each file is a Click command group
- Commands registered via `cli.add_command()` in `__init__.py`
- Commands delegate logic to engines (no business logic here)
- Rich library used for formatted terminal output
