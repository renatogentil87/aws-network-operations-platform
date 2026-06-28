# Systems Manager Module

Here you create the SSM module for operational automation.

## Files to Create

- `documents.tf` — SSM Automation documents for network runbooks
- `parameters.tf` — Parameter Store entries for network config
- `maintenance-windows.tf` — Maintenance windows for scheduled tasks
- `variables.tf` — Input variables
- `outputs.tf` — Document ARNs, parameter names

## What This Provisions

- SSM documents for network runbooks (VPN restart, route fix)
- Parameter Store for network configuration values
- Maintenance windows for scheduled network maintenance
- Automation execution roles

## Design Notes

- Documents are versioned and support approval workflows
- Parameter Store holds dynamic config (thresholds, endpoints)
- Maintenance windows prevent changes during business hours
