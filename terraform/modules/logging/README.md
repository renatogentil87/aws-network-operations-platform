# Centralized Logging Module

Here you create the centralized logging module for network telemetry.

## Files to Create

- `flow-logs.tf` — VPC and TGW flow log resources
- `dns-logs.tf` — Route53 DNS query logging
- `s3.tf` — Log destination S3 buckets
- `variables.tf` — Input variables
- `outputs.tf` — Log group ARNs, S3 bucket names

## What This Provisions

- VPC Flow Logs (delivered to both S3 and CloudWatch Logs)
- TGW Flow Logs for inter-VPC traffic visibility
- DNS query logs for Route53 resolver
- S3 buckets with lifecycle policies for log retention
- Cross-account log aggregation via S3 bucket policy

## Design Notes

- Dual-delivery (S3 for long-term, CloudWatch for real-time)
- S3 logs partitioned by account/region/date for Athena queries
- Log retention: 90 days CloudWatch, 1 year S3
