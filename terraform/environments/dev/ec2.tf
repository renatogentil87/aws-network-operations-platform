
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
  allowed_https_cidrs = ["64.43.143.251/32"]
  allowed_ssh_cidrs = ["64.43.143.251/32"]
}
