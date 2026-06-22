# Phase 3: Observability Platform

## Objective

Build a comprehensive observability layer for the network platform — centralized logging, metrics, alarms, and dashboards that provide visibility into network health, traffic patterns, and anomalies.

## Deliverables

1. **VPC Flow Logs** — Centralized flow log collection across all VPCs
2. **CloudWatch metrics & alarms** — TGW, NAT Gateway, VPN tunnel metrics with threshold alerts
3. **Centralized logging** — Log aggregation to a dedicated logging account/bucket
4. **CloudWatch dashboards** — Per-region and cross-region network health views
5. **EventBridge rules** — Event-driven notifications for network state changes
6. **Log analytics** — Athena tables for querying flow logs at scale

## Detailed Implementation

### 1. VPC Flow Logs Architecture

- All VPCs publish flow logs to a centralized S3 bucket (logging account)
- Log format: Custom (include all fields for Athena compatibility)
- Aggregation interval: 1 minute (production), 10 minutes (non-prod)
- Partition by: account-id / region / year / month / day

### 2. CloudWatch Metrics & Alarms

| Resource | Key Metrics | Alarm Threshold |
|----------|-------------|-----------------|
| Transit Gateway | BytesIn/Out, PacketsIn/Out, PacketDropCount | PacketDropCount > 0 for 5 min |
| NAT Gateway | BytesOutToDestination, ErrorPortAllocation, PacketsDropCount | ErrorPortAllocation > 0 |
| VPN Tunnels | TunnelState, TunnelDataIn/Out | TunnelState = 0 (down) |
| Route 53 | HealthCheckStatus | Status = 0 (unhealthy) |
| Network Firewall (future) | DroppedPackets, PassedPackets | Drop rate > threshold |

### 3. Centralized Logging Design

```
Spoke Accounts                    Logging Account
┌──────────┐                    ┌──────────────────┐
│ VPC Flow │───── S3 Repl ─────►│ Central S3 Bucket│
│ Logs     │                    │ (Partitioned)    │
└──────────┘                    ├──────────────────┤
                                │ Athena Tables    │
                                │ Glue Catalog     │
                                └──────────────────┘
```

### 4. CloudWatch Dashboards

- **Regional Dashboard** — Per-region: TGW throughput, NAT GW utilization, VPN status
- **Cross-Region Dashboard** — TGW peering traffic, latency between regions
- **Cost Dashboard** — Data transfer by VPC, NAT GW costs, flow log storage

### 5. EventBridge Rules

| Event | Source | Action |
|-------|--------|--------|
| VPN tunnel down | aws.vpn | SNS → Slack/PagerDuty |
| TGW attachment state change | aws.ec2 | SNS notification |
| Route table change | CloudTrail | Log + alert if unexpected |
| Security group change | CloudTrail | Log + validate against policy |

### 6. Terraform Modules

- `modules/cloudwatch/` — Alarms, dashboards, metric filters
- `modules/logging/` — Flow log configuration, S3 bucket, Glue catalog, Athena workgroup
- `modules/eventbridge/` — Event rules, targets, SNS topics

## Acceptance Criteria

- [ ] Flow logs enabled on all VPCs and arriving in central S3 bucket
- [ ] Athena query successfully returns flow log data
- [ ] CloudWatch alarms fire when TGW drops packets (tested via chaos)
- [ ] VPN tunnel down alarm triggers within 1 minute
- [ ] Dashboards render correctly with live data
- [ ] EventBridge rules capture and notify on network state changes

## Dependencies

- Phase 1 & 2 complete (VPCs and TGW exist to monitor)
- Logging account provisioned
- SNS topics / notification targets configured

## Estimated Effort

3–4 days
