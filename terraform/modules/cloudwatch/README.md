# CloudWatch Observability Module

Here you create the observability module for network monitoring.

## Files to Create

- `log-groups.tf` — CloudWatch Log groups for network logs
- `metric-filters.tf` — Metric filters for pattern detection
- `dashboards.tf` — CloudWatch dashboards
- `alarms.tf` — Individual and composite alarms
- `variables.tf` — Input variables
- `outputs.tf` — Dashboard URLs, alarm ARNs

## What This Provisions

- Log groups for VPN, TGW, and flow log data
- Metric filters for BGP flap detection and tunnel down events
- Dashboards for network health visibility
- Alarms with SNS notification targets
- Composite alarms for correlated failure detection

## Design Notes

- Metric filters parse VPN log patterns for BGP state changes
- Composite alarms reduce alert noise by correlating events
- Dashboard auto-discovery via tags
