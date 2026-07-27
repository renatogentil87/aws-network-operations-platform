terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# IAM Role for EC2 (SSM access)
resource "aws_iam_role" "this" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.instance_name}-role"
  }
}

# Attach SSM policy to the role
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile wraps the role for EC2
resource "aws_iam_instance_profile" "this" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.this.name
}

# Security Group
resource "aws_security_group" "this" {
  name        = "${var.instance_name}-sg"
  description = "Security group for ${var.instance_name}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# SSH inbound rule
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count             = length(var.allowed_ssh_cidrs) > 0 ? length(var.allowed_ssh_cidrs) : 0
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.allowed_ssh_cidrs[count.index]
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# HTTPS inbound rule (EVE-NG web UI)
resource "aws_vpc_security_group_ingress_rule" "https" {
  count             = length(var.allowed_https_cidrs) > 0 ? length(var.allowed_https_cidrs) : 0
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.allowed_https_cidrs[count.index]
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# HTTP inbound rule (EVE-NG web UI)
resource "aws_vpc_security_group_ingress_rule" "http" {
  count             = length(var.allowed_https_cidrs) > 0 ? length(var.allowed_https_cidrs) : 0
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.allowed_https_cidrs[count.index]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# EC2 Instance
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name = var.instance_name
  }

  lifecycle {
    ignore_changes = [ami]  # Prevent replacement when a newer AMI is found
  }
}
