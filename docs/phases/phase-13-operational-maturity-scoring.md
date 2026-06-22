# Phase 13: Operational Maturity Scoring

## Objective

Build the `netops score` command — assess the overall operational maturity of the network platform against a defined rubric, producing a quantitative score with improvement recommendations.

## Deliverables

1. **Scoring rubric** — Weighted criteria across operational dimensions
2. **Automated assessment** — Score calculated from live data (not self-assessment)
3. **Dimension breakdown** — Per-category scores with gap identification
4. **Improvement roadmap** — Prioritized recommendations to increase score
5. **Trend tracking** — Score history over time (are we improving?)

## Detailed Implementation

### 1. Scoring Dimensions

| Dimension | Weight | What It Measures |
|-----------|--------|-----------------|
| Infrastructure as Code | 15% | % of resources managed by Terraform (vs. manual) |
| Resilience | 20% | Multi-AZ, multi-region, failover configured and tested |
| Observability | 15% | Flow logs, alarms, dashboards coverage |
| Security | 15% | SG rules, NACLs, encryption, least privilege |
| Automation | 15% | Recovery playbooks, drift remediation, CI/CD |
| Testing | 10% | Connectivity tests, chaos experiments run frequency |
| Documentation | 10% | Runbooks, architecture docs, ADRs current |

### 2. Scoring Rubric (per dimension)

Each dimension scored 0–100:

| Score | Level | Description |
|-------|-------|-------------|
| 0–20 | Initial | Ad-hoc, no standards |
| 21–40 | Developing | Some practices in place, inconsistent |
| 41–60 | Defined | Standards exist, partially implemented |
| 61–80 | Managed | Consistently implemented, measured |
| 81–100 | Optimized | Continuous improvement, fully automated |

### 3. Assessment Criteria (Examples)

**Infrastructure as Code (15%)**
| Criteria | Points | How Measured |
|----------|--------|-------------|
| All VPCs in Terraform | 20 | Terraform state vs. inventory comparison |
| All TGW config in Terraform | 20 | Terraform state vs. inventory |
| All route tables in Terraform | 20 | Terraform state vs. inventory |
| Zero drift in last 7 days | 20 | Drift detection history |
| CI/CD pipeline for all changes | 20 | CloudTrail — all changes from CI/CD role |

**Resilience (20%)**
| Criteria | Points | How Measured |
|----------|--------|-------------|
| Multi-AZ NAT Gateways | 15 | Inventory check |
| Multi-region TGW peering active | 15 | Inventory check |
| DNS failover configured | 15 | Validation rule NET-008 |
| VPN redundancy (2 tunnels UP) | 15 | Validation rule NET-005 |
| Chaos experiment run in last 30 days | 20 | Experiment history |
| Recovery playbook tested | 20 | Recovery execution history |

**Observability (15%)**
| Criteria | Points | How Measured |
|----------|--------|-------------|
| Flow logs on all VPCs | 25 | Validation rule NET-007 |
| CloudWatch alarms for key metrics | 25 | Alarm inventory |
| Dashboard exists and current | 25 | Dashboard last update time |
| Log retention ≥ 90 days | 25 | Flow log bucket lifecycle |

### 4. Command Interface

```bash
# Run full maturity assessment
netops score

# Score specific dimension
netops score --dimension resilience
netops score --dimension security

# Show improvement recommendations
netops score --recommendations

# Compare with previous assessment
netops score --trend

# Output for CI/CD (exit code based on threshold)
netops score --minimum 70 --fail-below
```

### 5. Score Output

```
╔════════════════════════════════════════════════════════╗
║       OPERATIONAL MATURITY SCORECARD                   ║
║       Assessment Date: 2026-06-22                     ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║   OVERALL SCORE:  74 / 100   [████████████░░░░]  🟡    ║
║   Level: MANAGED                                       ║
║                                                        ║
╠════════════════════════════════════════════════════════╣
║   Infrastructure as Code  │  85/100  │ ████████████░░  ║
║   Resilience              │  70/100  │ ██████████░░░░  ║
║   Observability           │  90/100  │ █████████████░  ║
║   Security                │  65/100  │ █████████░░░░░  ║
║   Automation              │  72/100  │ ██████████░░░░  ║
║   Testing                 │  60/100  │ ████████░░░░░░  ║
║   Documentation           │  55/100  │ ███████░░░░░░░  ║
╠════════════════════════════════════════════════════════╣
║   TOP RECOMMENDATIONS:                                 ║
║   1. Run chaos experiment (last run: 45 days ago)      ║
║   2. Add missing SG rules to Terraform (3 manual SGs)  ║
║   3. Update architecture ADR (last update: 90 days)    ║
╚════════════════════════════════════════════════════════╝
```

### 6. Trend Tracking

- Score saved after each assessment to `~/.netops/scores/`
- `netops score --trend` shows score over last 12 assessments
- Useful for: quarterly reviews, demonstrating improvement, justifying investment

```
Score Trend (last 6 months):
Jan: 45 ▁▁▁▁▁
Feb: 52 ▂▂▂▂▂▂
Mar: 61 ▄▄▄▄▄▄▄
Apr: 68 ▅▅▅▅▅▅▅▅
May: 72 ▆▆▆▆▆▆▆▆▆
Jun: 74 ▇▇▇▇▇▇▇▇▇
```

## Acceptance Criteria

- [ ] All 7 dimensions produce automated scores (no manual input required)
- [ ] Overall score correctly calculated as weighted average
- [ ] Recommendations are actionable and prioritized by impact
- [ ] Score history persists and trend comparison works
- [ ] `--minimum` flag correctly gates CI/CD pipelines
- [ ] Score correlates with actual operational incidents (validated over time)

## Dependencies

- All previous phases complete (scoring draws from every engine)
- Sufficient historical data for trend (minimum 2 assessments)

## Estimated Effort

3–4 days
