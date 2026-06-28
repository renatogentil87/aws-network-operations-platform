# EventBridge Module

Here you create the event-driven automation module.

## Files to Create

- `rules.tf` — EventBridge rules for network events
- `targets.tf` — Rule targets (Lambda, SNS, SSM)
- `variables.tf` — Input variables
- `outputs.tf` — Rule ARNs

## What This Provisions

- EventBridge rules for VPN tunnel state changes (UP/DOWN)
- Rules for TGW route table changes
- Rules for VPC route modifications
- Auto-remediation triggers (invoke SSM runbooks or Lambda)
- Event pattern matching for specific failure scenarios

## Design Notes

- Events trigger automated response within seconds
- Targets include SSM Automation for runbook execution
- Supports cross-account event bus forwarding
- Dead-letter queues for failed event delivery
