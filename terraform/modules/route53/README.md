# Route53 DNS Module

Here you create the DNS module for private DNS resolution.

## Files to Create

- `hosted-zones.tf` — Private hosted zones
- `resolver.tf` — Resolver endpoints and rules
- `variables.tf` — Input variables
- `outputs.tf` — Zone IDs, resolver endpoint IPs

## What This Provisions

- Private hosted zones for internal service discovery
- Resolver inbound endpoints (on-prem → AWS DNS queries)
- Resolver outbound endpoints (AWS → on-prem DNS queries)
- Resolver rules (conditional forwarding)
- PHZ associations to VPCs across accounts

## Design Notes

- Enables hybrid DNS resolution between AWS and on-prem
- Resolver endpoints deployed in multiple AZs
- Supports cross-account PHZ association via RAM
