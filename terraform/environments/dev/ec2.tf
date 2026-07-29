# =============================================================================
# EVE-NG Instance — MANAGED MANUALLY (NOT by Terraform)
# =============================================================================
#
# The EVE-NG c5.metal instance is intentionally managed outside Terraform.
# It was removed from Terraform on Jul 29, 2026 because the pipeline kept
# replacing the instance (destroying labs and images) on every code push.
#
# Instance details:
#   Instance ID: i-04939401fd6d01d7f
#   Type: c5.metal
#   AMI: ami-099541a07a9bdb365 (Ubuntu 22.04)
#   Key: eu-west-1-keypair
#   Security Group: sg-077bd78afdc4130f9 (eveng-manual-sg)
#   EBS: 100GB gp3, DeleteOnTermination=false (volume persists)
#   Tag: ManagedBy=manual-not-terraform
#
# To update SG rules:
#   aws ec2 authorize-security-group-ingress --group-id sg-077bd78afdc4130f9 \
#     --protocol tcp --port 22 --cidr YOUR_IP/32 --region eu-west-1
#
# To start/stop:
#   aws ec2 start-instances --instance-ids i-04939401fd6d01d7f --region eu-west-1
#   aws ec2 stop-instances --instance-ids i-04939401fd6d01d7f --region eu-west-1
#
# =============================================================================
