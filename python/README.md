# Python Package Configuration

Here you create the package definition for the netops CLI tool.

## Files to Create

- `pyproject.toml` — Package metadata, dependencies, and CLI entry point

## Entry Point

- Console script: `netops` → `netops.commands:cli`

## Dependencies

- `click` — CLI framework
- `boto3` — AWS SDK
- `pyyaml` — YAML config parsing
- `rich` — Formatted terminal output (tables, progress bars)
- `pytest` — Testing (dev dependency)
- `moto` — AWS mocking (dev dependency)

## Design Notes

- Install in editable mode during development: `pip install -e .`
- Entry point makes `netops` available as a shell command
