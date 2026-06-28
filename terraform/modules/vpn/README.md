# VPN Module

Here you create the Site-to-Site VPN module to connect on-prem to AWS.

## Files to Create

- `vpn.tf` — VPN connection and customer gateway
- `variables.tf` — Input variables (peer IP, ASN, tunnel options)
- `outputs.tf` — VPN ID, tunnel IPs, BGP status

## What This Provisions

- Customer Gateway (on-prem router representation)
- VPN Connection attached to Transit Gateway
- Tunnel options (pre-shared keys, inside CIDR, DPD settings)
- BGP configuration (local/remote ASN, route advertisements)

## Design Notes

- Connects on-prem GNS3 simulated routers to AWS TGW
- Two tunnels per VPN for redundancy
- BGP dynamic routing preferred over static routes
- Supports multiple VPN connections for redundancy
