variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "renatogentil87/aws-network-operations-platform"
}

variable "github_branch" {
  description = "Branch to trigger pipeline"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = "CodeStar connection ARN for GitHub"
  type        = string
  default     = "arn:aws:codestar-connections:eu-west-1:MANAGEMENT_ACCOUNT_ID:connection/c0842346-8beb-4d28-8be3-d2a279692808"
}

variable "terraform_version" {
  description = "Terraform version for CodeBuild"
  type        = string
  default     = "1.14.9"
}

variable "network_account_id" {
  description = "AWS Account ID for the Network account"
  type        = string
  default     = "NETWORK_ACCOUNT_ID"
}

variable "perimeter_account_id" {
  description = "AWS Account ID for the Perimeter account"
  type        = string
  default     = "PERIMETER_ACCOUNT_ID"
}

variable "shared_services_account_id" {
  description = "AWS Account ID for the SharedServices account"
  type        = string
  default     = "SHARED_SERVICES_ACCOUNT_ID"
}

variable "spoke_account_id" {
  description = "AWS Account ID for the SpokeDev1 account"
  type        = string
  default     = "SPOKE_DEV1_ACCOUNT_ID"
}

variable "spoke2_account_id" {
  description = "AWS Account ID for the SpokeDev2 account"
  type        = string
  default     = "SPOKE_DEV2_ACCOUNT_ID"
}

variable "notification_email" {
  description = "Email address to receive plan output notifications"
  type        = string
  default     = "rrdog@amazon.com"
}
