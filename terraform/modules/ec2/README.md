# EC2 Module

## Purpose

Reusable module to deploy EC2 instances into spoke account VPCs. Initial use case: EVE-NG on a `.metal` instance in the Eveng account.

---

## Resources Needed

| Resource | Why |
|----------|-----|
| `aws_instance` | The EC2 instance itself |
| `aws_security_group` | Control inbound/outbound traffic (SSH, HTTPS for EVE-NG web UI) |
| `aws_key_pair` | SSH access to the instance |
| `aws_iam_instance_profile` | Attach an IAM role for SSM access (no need to expose SSH publicly) |
| `aws_iam_role` | Role for the instance profile (trust policy for ec2.amazonaws.com) |
| `aws_iam_role_policy_attachment` | Attach `AmazonSSMManagedInstanceCore` to the role |

---

## Variables to Define

| Variable | Description |
|----------|-------------|
| `instance_type` | e.g., `c5.metal` for EVE-NG, `t3.micro` for basic instances |
| `ami_id` | Ubuntu 22.04 AMI (EVE-NG requirement) |
| `subnet_id` | Which subnet to place the instance in (public for EVE-NG web access, or private + SSM) |
| `vpc_id` | For security group creation |
| `key_pair_name` | Name of the SSH key pair |
| `instance_name` | Name tag |
| `root_volume_size` | Disk size in GB (100+ for EVE-NG images) |
| `associate_public_ip` | Boolean — true if in public subnet and needs direct access |
| `allowed_ssh_cidrs` | List of CIDRs allowed to SSH in (your IP only) |
| `allowed_https_cidrs` | List of CIDRs for web UI access (EVE-NG runs on port 443) |

---

## Outputs to Export

- `instance_id`
- `private_ip`
- `public_ip` (if applicable)
- `security_group_id`

---

## Key Pair Approach

Two options:

1. **Create the key pair outside the module** (preferred) — generate locally with `ssh-keygen`, import the public key with `aws_key_pair`, pass the key name into the module. Private key stays on your laptop only.

2. **Create inside the module with `tls_private_key`** — stores the private key in state (less secure). Avoid this.

**Recommendation:** Create key pair once in `main.tf` or manually via CLI, pass name as variable.

---

## SSM vs SSH

For a metal instance running EVE-NG, you'll want **both**:

- **SSM Session Manager** — for management/admin access without opening SSH to the internet. Requires the IAM instance profile with `AmazonSSMManagedInstanceCore`.
- **Security Group with HTTPS (443)** — for accessing the EVE-NG web UI from your browser. Restrict to your IP.
- **SSH (22)** — optional if you prefer SSH over SSM. Restrict to your IP if enabled.

---

## EVE-NG Specific Notes

- Instance type must be `.metal` (e.g., `c5.metal`, `m5.metal`) — nested virtualisation required
- AMI: Ubuntu 22.04 LTS (Jammy Jellyfish) — required by EVE-NG installer
- Root volume: minimum 100 GB (SSD/gp3), more if loading many router images
- Place in **public subnet** with a public IP — you access EVE-NG via `https://<public-ip>`
- After instance is up, SSH in and run the EVE-NG install script
- Consider a stop/start schedule to control costs (metal instances are ~$4/hr)

---

## Implementation Order

1. Create `variables.tf` — define all inputs above
2. Create `main.tf` — IAM role, instance profile, security group, instance
3. Create `outputs.tf` — expose instance ID, IPs, SG ID
4. Call the module from `environments/dev/main.tf` with Eveng provider
5. Pass `subnet_id` from `module.eveng_vpc` outputs (you'll need to add public subnet output to vpc module)

---

## Cost Awareness

| Instance | On-Demand (eu-west-1) | Notes |
|----------|----------------------|-------|
| c5.metal | ~$4.08/hr | 96 vCPU, 192 GB RAM — overkill but cheapest metal |
| m5.metal | ~$5.42/hr | 96 vCPU, 384 GB RAM |
| c5n.metal | ~$4.85/hr | Better networking if needed |

**Tip:** Stop the instance when not in use. Metal instances don't support hibernate, so stop/start is your only option. Consider a Lambda or EventBridge rule to auto-stop after hours.
