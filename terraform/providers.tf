terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# NOTE: This configuration manages ONLY AWS resources. The Kubernetes DB
# secrets are intentionally NOT created here — they are created with kubectl in
# the deploy workflow. Managing kubernetes_* resources in the same apply that
# creates the EKS cluster causes the provider to fall back to localhost
# whenever the cluster does not yet exist (e.g. a rebuild), which breaks plan
# and destroy. Keeping Terraform AWS-only avoids that entirely.
