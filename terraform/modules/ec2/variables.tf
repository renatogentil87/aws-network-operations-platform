
variable "instance_type" {
        description = "Instance type"
        type = string
}
variable "ami_id" {
  description = "ami id"
  type = string
}

variable "subnet_id" {
  description = "subnet id"
  type = string
}
variable "key_pair_name" {
  description = "key pair name"
  type = string
}

variable "vpc_id" {
  description = "vpc id"
  type = string
}


variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 100
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDRs allowed to SSH (port 22)"
  type        = list(string)
  default     = []
}

variable "allowed_https_cidrs" {
  description = "List of CIDRs allowed to access web UI (port 443)"
  type        = list(string)
  default     = []
}
