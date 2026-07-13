variable "associations" {
  description = "Map of TGW route table associations (attachment → route table)"
  type = map(object({
    attachment_id  = string
    route_table_id = string
  }))
  default = {}
}

variable "propagations" {
  description = "Map of TGW route table propagations (attachment routes → into route table)"
  type = map(object({
    attachment_id  = string
    route_table_id = string
  }))
  default = {}
}

variable "static_routes" {
  description = "Map of static routes (including blackholes)"
  type = map(object({
    destination    = string
    route_table_id = string
    attachment_id  = optional(string)
    blackhole      = optional(bool, false)
  }))
  default = {}
}
