# Route Tables Module

Here you create route table management for VPC routing.

## Files to Create

- `route-tables.tf` — VPC route table resources
- `routes.tf` — Individual route entries
- `variables.tf` — Input variables
- `outputs.tf` — Route table IDs

## What This Provisions

- VPC route tables (public, private, transit per AZ)
- Routes to Transit Gateway for cross-VPC traffic
- Routes to NAT Gateway for private subnet internet access
- Blackhole routes for security isolation
- Default routes and specific prefix routes

## Design Notes

- Tag-based route injection for dynamic route management
- Separate route tables per subnet tier for least-privilege routing
- Supports adding/removing routes without full table replacement
