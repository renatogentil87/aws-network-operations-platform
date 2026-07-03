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
  sensitive   = true
}

variable "terraform_version" {
  description = "Terraform version for CodeBuild"
  type        = string
  default     = "1.14.9"
}

variable "network_account_id" {
  description = "AWS Account ID for the Network account"
  type        = string
  sensitive   = true
}

variable "perimeter_account_id" {
  description = "AWS Account ID for the Perimeter account"
  type        = string
  sensitive   = true
}

variable "shared_services_account_id" {
  description = "AWS Account ID for the SharedServices account"
  type        = string
  sensitive   = true
}

variable "spoke_account_id" {
  description = "AWS Account ID for the SpokeDev1 account"
  type        = string
  sensitive   = true
}

variable "spoke2_account_id" {
  description = "AWS Account ID for the SpokeDev2 account"
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Email address to receive plan output notifications"
  type        = string
  default     = "rrdog@amazon.com"
}
