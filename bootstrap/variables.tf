variable "region" {
  description = "AWS region for the state backend and OIDC role"
  type        = string
  default     = "eu-west-1"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the deployer role, as owner/name"
  type        = string
  default     = "psamantaroy-tus/automation_customer-order-service-dissertation"
}
