# GitHub Actions Workflows

Here you create CI/CD workflows for the platform.

## Files to Create

- `pr-checks.yml` — Runs on PR: terraform fmt, validate, plan, checkov, tfsec, pylint, pytest
- `deploy.yml` — Runs on merge to main: terraform apply, then netops validate + test + report
- `destroy.yml` — Manual trigger workflow for environment teardown

## Design Notes

- PR checks must pass before merge is allowed
- Deploy workflow uses OIDC for keyless AWS authentication
- Terraform plan output posted as PR comment
- Deploy runs: apply → validate → test → report (fail-fast)
- Destroy requires manual approval step
- Matrix strategy for multi-environment deploys
