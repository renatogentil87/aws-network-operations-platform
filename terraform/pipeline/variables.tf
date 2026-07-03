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

variable "accounts_config_json" {
  description = "Initial value for the SSM parameter containing account tfvars. After creation, update via CLI only."
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Email address to receive plan output notifications"
  type        = string
  default     = "rrdog@amazon.com"
}
