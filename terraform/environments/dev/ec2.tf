
data "aws_ami" "ubuntu" {
  provider = aws.eveng
  most_recent = true
  owners = ["099720109477"]
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ssm_parameter" "eveng_allowed_cidrs" {
  provider = aws.eveng
  name     = "/eveng/allowed-cidrs"
}

module "ec2" {
  source = "../../modules/ec2"
   providers = {
    aws = aws.eveng
  }
  ami_id = data.aws_ami.ubuntu.id
  instance_type = "c5.metal"
  instance_name = "eveng-instance"
  subnet_id = module.eveng_vpc.public_subnet[0]
  key_pair_name = "eu-west-1-keypair"
  vpc_id = module.eveng_vpc.vpc_id
  associate_public_ip = true
  allowed_https_cidrs = split(",", data.aws_ssm_parameter.eveng_allowed_cidrs.value)
  allowed_ssh_cidrs   = split(",", data.aws_ssm_parameter.eveng_allowed_cidrs.value)
  depends_on = [aws_key_pair.ireland-key-pair]
}

data "aws_ssm_parameter" "ec2_public_key" {
  provider = aws.eveng
  name     = "/ec2/keypair/eu-west-1-public-key"
}

resource "aws_key_pair" "ireland-key-pair" {
  provider   = aws.eveng
  public_key = data.aws_ssm_parameter.ec2_public_key.value
  key_name   = "eu-west-1-keypair"
  tags       = { Name = "eveng-key-pair" }
}