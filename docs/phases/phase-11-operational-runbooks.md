# Phase 11: Operational Runbooks

## Objective

Build a library of SSM Automation runbooks for common network operations tasks — executable, auditable, and integrated with the `netops` CLI for both automated and operator-initiated workflows.

## Deliverables

1. **SSM Automation documents** — Runbooks for common network operations
2. **CLI integration** — `netops runbook` subcommand to list, execute, and track runbooks
3. **Approval steps** — Human approval gates for destructive operations
4. **Parameterized inputs** — Configurable runbooks (account, region, resource ID)
5. **Execution history** — Track who ran what, when, with what result

## Detailed Implementation

### 1. Runbook Library

| ID | Runbook | Trigger | Approval |
|----|---------|---------|----------|
| RUN-001 | VPN Tunnel Reset | Tunnel down alert | Auto |
| RUN-002 | NAT Gateway Replacement | NAT GW unhealthy | Manual |
| RUN-003 | Route Table Rollback | Drift detected | Manual |
| RUN-004 | TGW Attachment Reattach | Attachment detached | Manual |
| RUN-005 | Flow Logs Re-enable | Flow logs disabled | Auto |
| RUN-006 | DNS Failover Test | Scheduled (monthly) | Auto |
| RUN-007 | Cross-Region Connectivity Validate | Post-deployment | Auto |
| RUN-008 | Security Group Audit & Fix | SG drift detected | Manual |
| RUN-009 | Network Capacity Check | Scheduled (weekly) | Auto |
| RUN-010 | Incident Response — Isolate VPC | Security incident | Manual (emergency) |

### 2. Runbook Structure (SSM Document)

```yaml
schemaVersion: "0.3"
description: "Reset VPN tunnel when tunnel state is DOWN"
assumeRole: "{{ AutomationAssumeRole }}"
parameters:
  VpnConnectionId:
    type: String
    description: "VPN Connection ID"
  TunnelIp:
    type: String
    description: "Outside IP of the tunnel to reset"
mainSteps:
  - name: CheckTunnelState
    action: aws:executeAwsApi
    inputs:
      Service: ec2
      Api: DescribeVpnConnections
      VpnConnectionIds:
        - "{{ VpnConnectionId }}"
    outputs:
      - Name: TunnelState
        Selector: "$.VpnConnections[0].VgwTelemetry[0].Status"
  - name: ResetTunnel
    action: aws:executeAwsApi
    inputs:
      Service: ec2
      Api: ResetVpnTunnel
      VpnConnectionId: "{{ VpnConnectionId }}"
      VpnTunnelOutsideIpAddress: "{{ TunnelIp }}"
  - name: WaitForRecovery
    action: aws:sleep
    inputs:
      Duration: PT60S
  - name: ValidateRecovery
    action: aws:executeAwsApi
    inputs:
      Service: ec2
      Api: DescribeVpnConnections
      VpnConnectionIds:
        - "{{ VpnConnectionId }}"
```

### 3. CLI Integration

```bash
# List available runbooks
netops runbook list

# Execute a runbook
netops runbook execute RUN-001 --vpn-id vpn-0abc123 --tunnel-ip 1.2.3.4

# Dry-run (show steps without executing)
netops runbook execute RUN-001 --dry-run

# Check execution status
netops runbook status <execution-id>

# View execution history
netops runbook history --days 30
```

### 4. Terraform for Runbook Deployment

```
terraform/modules/systems-manager/
├── main.tf              # SSM document resources
├── variables.tf         # Runbook parameters
├── documents/           # YAML runbook definitions
│   ├── run-001-vpn-reset.yaml
│   ├── run-002-nat-replace.yaml
│   └── ...
└── iam.tf              # Automation assume role
```

### 5. EventBridge → SSM Integration

For automated runbook execution:
- EventBridge rule detects failure event (VPN down, NAT unhealthy)
- Target: SSM Automation with the corresponding runbook
- Parameters populated from event payload

## Acceptance Criteria

- [ ] All 10 runbooks deployed as SSM Automation documents
- [ ] CLI can list, execute, and track runbook executions
- [ ] Manual approval gates pause execution until approved
- [ ] Execution history shows who, when, what, result
- [ ] EventBridge-triggered runbooks execute automatically for auto-approved cases
- [ ] Dry-run mode shows planned steps without executing

## Dependencies

- Phase 4 complete (CLI framework)
- Phase 9 complete (recovery logic — runbooks implement the same actions with more structure)
- SSM Automation IAM roles deployed

## Estimated Effort

3–4 days
