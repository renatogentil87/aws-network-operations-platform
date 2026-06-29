variable "name" {
  description = "Description of the Transit Gateway"
  type = string
  default = "Central Transit Gateway"
}

variable "amazon_side_asn" {
  description = "ASN for the TGW"
  type = number
  default = 64512
}

variable "route_table_names" {
  description = "List of TGW route table name to create"
  type = list(string)
  default = ["shared", "spoke", "firewall","fullmesh"]
}

variable "organization_arn" {
  description = "AWS Organization ARN for RAM sharing"
  type = string
}
