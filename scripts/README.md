# Helper Scripts

Here you create shell scripts for bootstrap and operational tasks.

## Files to Create

- `bootstrap.sh` — Create S3 backend bucket + DynamoDB lock table for Terraform
- `assume-role.sh` — Wrapper to assume cross-account roles (exports credentials)
- `setup-gns3.sh` — Configure GNS3 lab topology (create routers, links, start nodes)

## Design Notes

- `bootstrap.sh` is run once per account to initialize Terraform backend
- `assume-role.sh` used for local development and debugging
- `setup-gns3.sh` automates GNS3 lab setup via REST API
- All scripts are idempotent (safe to re-run)
