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
