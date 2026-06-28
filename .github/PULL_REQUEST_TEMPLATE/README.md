# Pull Request Template

Here you create the PR template for consistent change reviews.

## Files to Create

- `network-change.md` — PR template for network infrastructure changes

## Template Checklist

- [ ] Terraform plan output attached
- [ ] No new security findings (checkov/tfsec clean)
- [ ] `netops validate` passes against target environment
- [ ] `netops test` connectivity checks pass
- [ ] Rollback plan documented
- [ ] Affected accounts/regions listed
- [ ] Change window confirmed (if prod)
