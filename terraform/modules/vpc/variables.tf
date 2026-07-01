variable "name" {
  description = "NetOps VPC"
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
