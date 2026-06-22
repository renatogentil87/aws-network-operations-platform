# Phase 7: Automated Network Testing

## Objective

Build the `netops test` command — an automated network testing suite that validates end-to-end connectivity, path correctness, latency, and reachability across the platform.

## Deliverables

1. **Connectivity tests** — Verify reachability between source/destination pairs
2. **Path validation** — Confirm traffic follows expected routing paths
3. **Latency measurement** — Baseline and threshold-based latency checks
4. **DNS resolution tests** — Validate DNS returns correct answers
5. **Segmentation tests** — Verify isolation (negative tests — things that should NOT connect)
6. **Test definitions** — YAML-based test specs (declarative)

## Detailed Implementation

### 1. Test Types

| Test Type | Method | Purpose |
|-----------|--------|---------|
| Connectivity | VPC Reachability Analyzer / ICMP / TCP | Can A reach B? |
| Path | VPC Reachability Analyzer | Does traffic flow through expected hops? |
| Latency | CloudWatch Network Monitor / ping | Is latency within threshold? |
| DNS | Route 53 Resolver query | Does name resolve to expected IP? |
| Segmentation | Negative connectivity test | Confirm A CANNOT reach B |
| Throughput | iperf3 (via SSM Run Command) | Bandwidth between endpoints |

### 2. Test Definition Format (YAML)

```yaml
tests:
  - name: "prod-to-shared-services"
    type: connectivity
    source:
      account: prod
      vpc: prod-vpc
      subnet_tier: private
    destination:
      account: network-hub
      vpc: shared-services-vpc
      port: 443
    expected: reachable
    timeout: 5s

  - name: "prod-to-nonprod-isolation"
    type: segmentation
    source:
      account: prod
      vpc: prod-vpc
    destination:
      account: non-prod
      vpc: dev-vpc
      port: 443
    expected: unreachable

  - name: "cross-region-latency"
    type: latency
    source:
      region: ca-central-1
      vpc: prod-vpc
    destination:
      region: us-east-1
      vpc: dr-prod-vpc
    threshold_ms: 30

  - name: "dns-failover-resolution"
    type: dns
    query: "api.platform.internal"
    expected_answer: "10.1.0.100"
    record_type: A
```

### 3. Command Interface

```bash
# Run all tests
netops test

# Run specific test category
netops test --type connectivity
netops test --type segmentation
netops test --type latency

# Run specific named test
netops test --name prod-to-shared-services

# Run with verbose output (show each hop)
netops test --verbose

# Output in CI-friendly format
netops test --output json --fail-on-error
```

### 4. Implementation Methods

**Connectivity (AWS-native):**
- VPC Reachability Analyzer — Analyzes path without sending traffic
- Network Insights Path — Create, analyze, get results
- Fallback: SSM Run Command to execute ping/curl from EC2 instances

**Latency:**
- CloudWatch Network Monitor (if available)
- SSM Run Command: `ping -c 10` between instances, parse RTT
- Store baseline, alert on deviation

**DNS:**
- Boto3 `route53resolver.resolve` or SSM Run Command `dig/nslookup`
- Validate A/CNAME records match expected values

**Segmentation:**
- Same as connectivity but `expected: unreachable`
- PASS if connection times out / is refused
- FAIL if connection succeeds (isolation broken)

### 5. Test Results Output

```
┌────────────────────────────────┬───────────────┬────────┬─────────┐
│ Test Name                      │ Type          │ Result │ Latency │
├────────────────────────────────┼───────────────┼────────┼─────────┤
│ prod-to-shared-services        │ connectivity  │ ✅ PASS │ 1.2ms   │
│ prod-to-nonprod-isolation      │ segmentation  │ ✅ PASS │ —       │
│ cross-region-latency           │ latency       │ ✅ PASS │ 18ms    │
│ dns-failover-resolution        │ dns           │ ✅ PASS │ —       │
│ dev-to-internet                │ connectivity  │ ❌ FAIL │ timeout │
└────────────────────────────────┴───────────────┴────────┴─────────┘

Summary: 4 PASS | 1 FAIL | 0 SKIP
```

## Acceptance Criteria

- [ ] Connectivity tests correctly identify reachable and unreachable paths
- [ ] Segmentation tests PASS when isolation holds and FAIL when broken
- [ ] Latency tests measure and compare against configurable thresholds
- [ ] DNS tests validate resolution answers
- [ ] Tests run without requiring pre-deployed test instances (use Reachability Analyzer where possible)
- [ ] Full test suite completes within 5 minutes
- [ ] JSON output suitable for CI/CD pass/fail gating

## Dependencies

- Phase 5 complete (inventory provides resource IDs for test source/destination)
- IAM permissions for Reachability Analyzer and SSM Run Command
- At least one EC2 instance per VPC for active tests (or use SSM-managed instances)

## Estimated Effort

4–5 days
