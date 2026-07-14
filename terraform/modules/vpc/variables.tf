variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "ipam_pool_id" {
  description = "IPAM pool ID to allocate the VPC CIDR from"
  type        = string
}

variable "netmask_length" {
  description = "Netmask length to request from IPAM (e.g., 22 for /22)"
  type        = number
  default     = 22
}

variable "availability_zones" {
  description = "List of availability zones to create TGW subnets in"
  type        = list(string)
}

variable "tgw_subnet_newbits" {
  description = "Additional bits for TGW subnet CIDR (e.g., 6 gives /28 subnets from a /22 VPC)"
  type        = number
  default     = 6
}

variable "public_subnet" {
  description = "Additional bits for public subnet (eg., 6 /28 subnet from a /22 vpc)"
  type = number
  default = 6
}

variable "private_subnet" {
  description = "additional bits for private subnet"
  type = number
  default = 6
}

variable "notg_vpc_tags" {
  description = "NOTG tags for the VPC (Associate-with, Propagate-to)"
  type        = map(string)
  default     = {}
}

variable "notg_subnet_tags" {
  description = "NOTG tags for TGW subnets (Attach-to-tgw)"
  type        = map(string)
  default     = {}
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID for priavte route default route"
  type = string
}

variable "tgw_default_route" {
  description = "conditional configuration to add default route to TGW"
  type = bool
  default = true
}

variable "tgw_appliance_mode" {
  description = "Decide whether to turn on TGW appliance mode"
  type = bool
  default = false
}