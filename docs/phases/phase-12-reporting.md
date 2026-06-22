# Phase 12: Reporting

## Objective

Build the `netops report` command — generate comprehensive reports (HTML dashboards, PDF summaries, JSON data) that communicate network health, compliance, and operational status to different audiences.

## Deliverables

1. **Executive summary** — High-level health status for leadership
2. **Technical report** — Detailed findings for engineering teams
3. **Compliance report** — Policy adherence for audit/governance
4. **Trend reports** — Week-over-week and month-over-month comparisons
5. **Multiple output formats** — HTML (interactive), PDF (printable), JSON (data)

## Detailed Implementation

### 1. Report Types

| Report | Audience | Content | Frequency |
|--------|----------|---------|-----------|
| Executive Summary | Leadership | Health score, top risks, cost trends | Weekly/Monthly |
| Technical Report | Engineering | Full validation results, drift, test results | Per deployment |
| Compliance Report | Audit/GRC | Policy adherence, exceptions, remediation status | Monthly |
| Incident Report | Operations | Post-incident: timeline, impact, recovery | Per incident |
| Capacity Report | Planning | Subnet utilization, IP exhaustion risk | Weekly |

### 2. Command Interface

```bash
# Generate all reports
netops report

# Specific report type
netops report --type executive
netops report --type technical
netops report --type compliance
netops report --type capacity

# Output format
netops report --format html   # Interactive dashboard
netops report --format pdf    # Printable document
netops report --format json   # Raw data for further processing

# Custom date range
netops report --from 2026-06-01 --to 2026-06-22

# Save to specific location
netops report --output ./reports/
```

### 3. Executive Summary Content

```
╔════════════════════════════════════════════╗
║    NETWORK OPERATIONS - EXECUTIVE SUMMARY  ║
║    Week of June 16–22, 2026               ║
╠════════════════════════════════════════════╣
║                                            ║
║  Overall Health Score:  92/100  🟢         ║
║                                            ║
║  ┌─────────────────────────────────────┐   ║
║  │ Validation:  48/50 rules passing    │   ║
║  │ Connectivity: 100% tests passing    │   ║
║  │ Drift:       0 critical findings    │   ║
║  │ Recovery:    2 auto-recoveries      │   ║
║  │ Availability: 99.99% (target 99.9%) │   ║
║  └─────────────────────────────────────┘   ║
║                                            ║
║  Top Risks:                                ║
║  1. VPN tunnel flapping (3x this week)     ║
║  2. Subnet 10.1.2.0/24 at 85% IP usage    ║
║                                            ║
║  Actions Taken:                            ║
║  • REC-002 auto-executed (VPN reset)       ║
║  • NET-015 remediated (unused NAT GW)      ║
╚════════════════════════════════════════════╝
```

### 4. HTML Dashboard Components

- Network topology visualization (D3.js or similar)
- Health status heatmap (accounts × regions)
- Trend charts (validation pass rate over time)
- Drill-down tables (click finding → details)
- Export buttons (PDF, CSV)

### 5. Data Sources

Reports aggregate data from all previous phases:
- Inventory (Phase 5) → Resource counts, topology
- Validation (Phase 6) → Compliance findings
- Testing (Phase 7) → Connectivity results
- Drift (Phase 8) → Configuration changes
- Recovery (Phase 9) → Remediation actions
- Chaos (Phase 10) → Resilience test results
- Runbooks (Phase 11) → Operational activity

### 6. Report Storage

- Reports saved to `~/.netops/reports/YYYY-MM-DD/`
- Historical reports retained for trend analysis
- Optional: Upload to S3 for team access

## Acceptance Criteria

- [ ] Executive summary generates with correct health score calculation
- [ ] HTML report renders interactive dashboard with live data
- [ ] PDF report is formatted and printable
- [ ] Trend data shows week-over-week comparison
- [ ] Report aggregates data from all engines (inventory, validate, test, drift)
- [ ] Report generation completes within 30 seconds
- [ ] Reports accessible via S3 upload (optional)

## Dependencies

- Phases 5–11 complete (data sources for report content)
- Historical data available (at least 2 weeks of snapshots for trends)

## Estimated Effort

4–5 days
