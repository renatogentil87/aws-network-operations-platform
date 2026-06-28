# Tests

Here you create pytest tests for the netops CLI and engines.

## Directory Structure

- `unit/` — Unit tests with mocked AWS calls (using moto)
- `integration/` — Integration tests against real AWS (dev account)
- `gns3/` — GNS3 integration tests (verify BGP routes from simulated routers)
- `conftest.py` — Shared fixtures (mock sessions, sample configs)

## Design Notes

- Unit tests use moto to mock all AWS service calls
- Integration tests run in dev account only (tagged resources)
- GNS3 tests require running GNS3 server (skipped in CI by default)
- pytest markers: `@pytest.mark.unit`, `@pytest.mark.integration`, `@pytest.mark.gns3`
- Coverage target: 80%+ for engines, 60%+ for commands
