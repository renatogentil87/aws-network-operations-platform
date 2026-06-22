# Phase 10: Chaos Engineering

## Objective

Build the `netops chaos` command — controlled failure injection to validate that the platform's monitoring, alerting, failover, and recovery mechanisms work as expected under real failure conditions.

## Deliverables

1. **Chaos experiments** — Predefined failure injections for network components
2. **Steady-state validation** — Confirm system health before and after experiments
3. **Blast radius controls** — Scope limitations and automatic abort conditions
4. **Experiment reports** — Document what happened, what was detected, what recovered
5. **AWS FIS integration** — Use AWS Fault Injection Service where applicable

## Detailed Implementation

### 1. Chaos Experiments

| ID | Experiment | What It Tests |
|----|-----------|---------------|
| CHAOS-001 | Delete a route from TGW route table | Drift detection + recovery playbook |
| CHAOS-002 | Disable one VPN tunnel | Monitoring alerts + tunnel failover |
| CHAOS-003 | Stop NAT Gateway (delete + recreate) | HA detection + recovery |
| CHAOS-004 | Add rogue security group rule | Validation framework detection |
| CHAOS-005 | Blackhole a subnet's route table | Connectivity test failure detection |
| CHAOS-006 | Detach TGW VPC attachment | Cross-VPC connectivity break detection |
| CHAOS-007 | Modify DNS record TTL to 3600 | Validation rule NET-009 detection |
| CHAOS-008 | Disable VPC flow logs | Validation rule NET-007 detection |
| CHAOS-009 | Simulate region failure (disable health check endpoint) | DNS failover behavior |
| CHAOS-010 | Network ACL deny-all on a subnet | Segmentation test + alerting |

### 2. Command Interface

```bash
# List available experiments
netops chaos --list

# Dry-run (show what would be injected)
netops chaos --experiment CHAOS-001 --dry-run

# Execute experiment (requires --confirm)
netops chaos --experiment CHAOS-001 --confirm

# Execute with auto-rollback after N seconds
netops chaos --experiment CHAOS-001 --confirm --duration 300 --auto-rollback

# Run experiment and validate detection
netops chaos --experiment CHAOS-001 --confirm --validate-detection

# Abort a running experiment
netops chaos --abort
```

### 3. Experiment Lifecycle

```
1. PRE-CHECK
   ├── Validate steady state (netops validate + netops test = all pass)
   ├── Confirm experiment scope and blast radius
   └── Capture before-state snapshot

2. INJECT
   ├── Apply failure condition
   └── Start timer

3. OBSERVE
   ├── Wait for detection (alarm/drift/validation)
   ├── Record time-to-detect
   └── Record what alerted

4. VERIFY RECOVERY
   ├── Did auto-recovery trigger? (if applicable)
   ├── Record time-to-recover
   └── Validate post-recovery state

5. ROLLBACK
   ├── Restore original state (if not auto-recovered)
   └── Re-run steady-state validation

6. REPORT
   ├── Time to detect
   ├── Time to recover
   ├── What alerted (CloudWatch/EventBridge/drift)
   └── Pass/fail assessment
```

### 4. Safety Controls

| Control | Description |
|---------|-------------|
| Environment gate | Chaos only runs in `dev` and `test` by default. Prod requires `--override-prod-gate` |
| Blast radius | Max 1 resource affected per experiment |
| Auto-rollback | Default 5 minutes, configurable via `--duration` |
| Kill switch | `netops chaos --abort` immediately reverts |
| Steady-state check | Experiment won't start if environment is already unhealthy |
| Confirmation | Always requires `--confirm` flag |

### 5. AWS FIS Integration

Where possible, use AWS Fault Injection Service:
- FIS experiment templates for VPC/subnet disruption
- FIS stop conditions tied to CloudWatch alarms
- Benefits: managed rollback, audit trail, IAM-scoped blast radius

For network-specific injections not supported by FIS (route table manipulation, TGW changes), use direct API calls with manual rollback logic.

### 6. Experiment Report Output

```
╔══════════════════════════════════════════════════╗
║          CHAOS EXPERIMENT REPORT                  ║
╠══════════════════════════════════════════════════╣
║ Experiment:    CHAOS-001 (Delete TGW route)       ║
║ Environment:   dev                                ║
║ Target:        rtb-0abc123 (route 10.2.0.0/16)    ║
║ Duration:      300 seconds                        ║
╠══════════════════════════════════════════════════╣
║ DETECTION                                         ║
║ • CloudWatch alarm fired:     Yes (42s)           ║
║ • Drift detection caught:     Yes (next scan)     ║
║ • Connectivity test failed:   Yes (immediate)     ║
╠══════════════════════════════════════════════════╣
║ RECOVERY                                          ║
║ • Auto-recovery triggered:    Yes (REC-004)       ║
║ • Time to recover:            67 seconds          ║
║ • Post-recovery validation:   PASS                ║
╠══════════════════════════════════════════════════╣
║ RESULT:  ✅ PASS                                   ║
║ Detection: 42s | Recovery: 67s | Total: 109s      ║
╚══════════════════════════════════════════════════╝
```

## Acceptance Criteria

- [ ] At least 5 experiments execute successfully in dev environment
- [ ] Auto-rollback works correctly (state restored after duration)
- [ ] Kill switch (`--abort`) immediately reverts injected failure
- [ ] Experiment validates that monitoring/alerting detects the failure
- [ ] Experiment report accurately captures detection and recovery times
- [ ] Prod gate prevents accidental chaos in production
- [ ] Steady-state pre-check blocks experiment if environment is already broken

## Dependencies

- Phase 3 complete (observability — alarms must exist to validate detection)
- Phase 6 complete (validation — rules must exist to catch injected faults)
- Phase 9 complete (recovery — auto-remediation validates end-to-end)

## Estimated Effort

4–5 days
