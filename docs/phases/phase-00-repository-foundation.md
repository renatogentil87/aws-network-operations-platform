# Phase 0: Repository Foundation

## Objective

Establish the repository structure, CI/CD pipelines, state management, and development standards that all subsequent phases build upon.

## Deliverables

1. **Repository scaffold** — Complete folder structure with placeholder files
2. **Terraform backend** — S3 bucket + DynamoDB lock table for remote state (per account/env/region)
3. **CI/CD pipelines** — GitHub Actions workflows for PR validation and merge deployment
4. **Development standards** — Pre-commit hooks, linting config, commit conventions
5. **Documentation skeleton** — ADR template, runbook template, phase plan template

## Detailed Implementation

### 1. State Management Bootstrap

Create a bootstrap Terraform configuration that provisions:
- S3 bucket for state storage (versioning enabled, encryption at rest, block public access)
- DynamoDB table for state locking (partition key: `LockID`)
- IAM role for CI/CD pipeline to assume (OIDC federation with GitHub)

State key convention:
```
s3://<org>-terraform-state/<account-id>/<environment>/<region>/terraform.tfstate
```

### 2. GitHub Actions Pipelines

**PR Workflow (`.github/workflows/pr-validate.yml`):**
- Trigger: Pull request to `main`
- Steps: fmt check → validate → plan → checkov → tfsec → python lint → pytest
- Output: Plan summary as PR comment

**Deploy Workflow (`.github/workflows/deploy.yml`):**
- Trigger: Push to `main`
- Steps: init → plan → apply → netops validate → netops test → netops report
- Environment gates: dev (auto) → test (manual approval) → prod (manual approval)

**Drift Detection (`.github/workflows/drift-check.yml`):**
- Trigger: Scheduled (daily)
- Steps: terraform plan (detect drift) → notify on changes

### 3. Development Standards

- **Pre-commit hooks:** terraform-fmt, terraform-validate, python black/ruff, trailing whitespace
- **Commit convention:** Conventional Commits (feat/fix/docs/chore)
- **Branch strategy:** `main` (protected), feature branches, no direct commits
- **PR template:** Description, testing done, phase reference, checklist

### 4. Configuration Files

- `.gitignore` — Terraform state, Python cache, IDE files, .env
- `.pre-commit-config.yaml` — Hook definitions
- `configs/checkov.yaml` — Security scan configuration
- `configs/tfsec.yaml` — Terraform security rules
- `configs/pyproject.toml` — Python project config (black, ruff, pytest)

## Acceptance Criteria

- [ ] `terraform init` succeeds with remote backend
- [ ] PR pipeline runs on every pull request and posts plan output
- [ ] Merge to main triggers deployment pipeline
- [ ] State is isolated per account/environment/region
- [ ] Pre-commit hooks pass locally before push
- [ ] All team members can assume CI/CD role via OIDC

## Dependencies

- AWS account(s) provisioned
- GitHub repository created
- OIDC identity provider configured in AWS

## Estimated Effort

2–3 days
