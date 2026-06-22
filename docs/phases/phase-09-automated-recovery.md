# Phase 9: Automated Recovery

## Objective

Build the `netops recover` command — automated remediation for known network failure patterns, bringing the environment back to its desired state without manual intervention.

## Deliverables

1. **Recovery playbooks** — Predefined remediation actions for common failures
2. **Dry-run mode** — Show what WOULD be fixed without executing
3. **Approval workflow** — Critical recoveries require human approval
4. **Audit trail** — Every recovery action logged with before/after state
5. **Rollback capability** — Undo a recovery if it makes things worse

## Detailed Implementation

### 1. Recovery Playbooks

| ID | Trigger | Recovery Action | Auto/Manual |
|----|---------|-----------------|-------------|
| REC-001 | Blackhole route in TGW | Re-create missing attachment or remove route | Manual |
| REC-002 | VPN tunnel DOWN | Reset tunnel (toggle) via API | Auto |
| REC-003 | NAT Gateway unhealthy | Replace NAT GW in same AZ | Auto |
| REC-004 | Route deleted from VPC RT | Re-add route from Terraform state | Auto |
| REC-005 | Security group rule drift | Revert to Terraform-defined rules | Manual |
| REC-006 | TGW attachment wrong RT | Re-associate to correct route table | Manual |
| REC-007 | Flow logs disabled | Re-enable flow logs | Auto |
| REC-008 | DNS health check failing | Trigger failover (if not auto) | Auto |
| REC-009 | Route 53 record missing | Re-create from Terraform state | Manual |
| REC-010 | VPC endpoint deleted | Re-create endpoint | Auto |

### 2. Command Interface

```bash
# Show what needs recovery (dry-run by default)
netops recover

# Execute all auto-approved recoveries
netops recover --execute

# Execute specific playbook
netops recover --playbook REC-002 --execute

# Force execution of manual-approval playbooks (dangerous)
netops recover --playbook REC-001 --execute --force

# Show recovery history
netops recover --history

# Rollback last recovery
netops recover --rollback <recovery-id>
```

### 3. Recovery Workflow

```
Drift/Failure Detected
        │
        ▼
Match Recovery Playbook
        │
        ▼
┌───────────────────┐
│ Auto or Manual?   │
├───────┬───────────┤
│ Auto  │  Manual   │
│       │           │
▼       ▼           │
Execute  Wait for   │
Action   Approval   │
│       │           │
▼       ▼           │
Log Result          │
│                   │
▼                   │
Verify Fix          │
(re-run validate)   │
```

### 4. Safety Mechanisms

- **Dry-run by default** — Must pass `--execute` to take action
- **Blast radius limit** — Max 5 resources per recovery run (configurable)
- **Cooldown period** — Same playbook won't fire again for 15 minutes on same resource
- **Rollback state** — Capture before-state before every action
- **Kill switch** — `netops recover --disable` prevents all automated recovery

### 5. Audit Trail

Every recovery action recorded:
```json
{
  "recovery_id": "rec-2026-06-22-001",
  "playbook": "REC-002",
  "resource": "vpn-0abc123",
  "trigger": "tunnel_state=DOWN",
  "action": "reset_vpn_tunnel",
  "before_state": {"tunnel1": "DOWN", "tunnel2": "UP"},
  "after_state": {"tunnel1": "UP", "tunnel2": "UP"},
  "executed_by": "netops-pipeline",
  "timestamp": "2026-06-22T10:30:00Z",
  "rollback_available": true
}
```

### 6. Integration with EventBridge (Reactive Recovery)

For production, recovery can be triggered reactively:
- EventBridge detects VPN tunnel down → triggers Lambda → executes REC-002
- This is Phase 9 Advanced — implement after CLI-based recovery is proven

## Acceptance Criteria

- [ ] Dry-run mode shows planned actions without executing
- [ ] Auto-approved playbooks execute and fix the issue
- [ ] Manual-approval playbooks wait for confirmation
- [ ] Recovery audit trail captures before/after state
- [ ] Rollback successfully reverts a recovery action
- [ ] Blast radius limit prevents runaway remediation
- [ ] Post-recovery validation (re-run validate) confirms fix

## Dependencies

- Phase 6 complete (validation identifies what needs fixing)
- Phase 8 complete (drift detection triggers recovery)
- Write IAM permissions in target accounts (separate from read-only)

## Estimated Effort

4–5 days
