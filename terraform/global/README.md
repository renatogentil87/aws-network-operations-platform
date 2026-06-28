# Global / Shared Resources

Here you create global resources shared across all environments.

## Files to Create

- `backend.tf` — Bootstrap backend (local state initially)
- `s3.tf` — Terraform state S3 bucket with versioning
- `dynamodb.tf` — DynamoDB lock table for state locking
- `ipam.tf` — VPC IPAM pools and scopes
- `ram.tf` — RAM shares for cross-account resources
- `scps.tf` — Organization Service Control Policies

## What This Provisions

- S3 backend bucket for all environment state files
- DynamoDB table for Terraform state locking
- IPAM pools for automated CIDR allocation
- RAM shares for TGW and other shared resources
- Organization SCPs to enforce network guardrails
