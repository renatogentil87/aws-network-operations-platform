# Transit Gateway Module

Here you create the TGW module to provision hub-and-spoke network connectivity.

## Files to Create

- `tgw.tf` — Transit Gateway resource and attachments
- `route-tables.tf` — TGW route tables and associations
- `ram.tf` — Resource Access Manager shares for cross-account
- `variables.tf` — Input variables
- `outputs.tf` — TGW ID, route table IDs, attachment IDs

## What This Provisions

- Transit Gateway with auto-accept attachments
- TGW route tables: shared-services, prod, dev
- TGW VPC attachments (transit subnets)
- Route propagation and association rules
- RAM share for cross-account TGW access

## Design Notes

- Supports cross-account sharing via AWS RAM
- Route table segmentation isolates prod from dev traffic
- Blackhole routes for security isolation
