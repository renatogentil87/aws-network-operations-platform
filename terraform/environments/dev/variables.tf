variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "network_account_id" {
  description = "AWS Account ID for the Network account"
  type        = string
}

variable "perimeter_account_id" {
  description = "AWS Account ID for the Perimeter account"
  type        = string
}

variable "shared_services_account_id" {
  description = "AWS Account ID for the SharedServices account"
  type        = string
}

variable "spoke_account_id" {
  description = "AWS Account ID for the spoke workload account"
  type        = string
}

variable "spoke2_account_id" {
  description = "AWS Account ID for the second spoke workload account"
  type        = string
}

variable "eveng_account_id" {
  description = "AWS Account ID for Eveng environment"
  type = string
}