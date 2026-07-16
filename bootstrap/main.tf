# =============================================================================
# BOOTSTRAP — run ONCE, locally, before anything else.
# Creates:
#   1. S3 bucket + DynamoDB table  -> remote Terraform state backend
#   2. GitHub OIDC provider + IAM role -> lets GitHub Actions log into AWS
#      with short-lived tokens (no stored access keys).
#
# This config uses a LOCAL state file (bootstrap/terraform.tfstate) on purpose,
# because it is what creates the remote backend the rest of the project uses.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply -var="github_repo=psamantaroy-tus/automation_customer-order-service-dissertation"
#   terraform output          # copy the values into GitHub secrets
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
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

data "aws_caller_identity" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  state_bucket   = "tf-state-${local.account_id}-${var.region}"
  lock_table     = "tf-locks"
  oidc_role_name = "github-actions-deployer"
}

# -----------------------------------------------------------------------------
# 1. Remote state backend: S3 bucket (versioned + encrypted) and lock table
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket        = local.state_bucket
  force_destroy = true # allows clean teardown while experimenting
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# -----------------------------------------------------------------------------
# 2. GitHub OIDC provider + deployer role
# -----------------------------------------------------------------------------
# GitHub's public OIDC endpoint. AWS trusts tokens signed by this provider.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Trust policy: only workflows from THIS repo can assume the role.
data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = local.oidc_role_name
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

# Broad permissions so the pipeline can create/destroy the full stack.
# For a dissertation/test account this is acceptable; tighten for production.
resource "aws_iam_role_policy_attachment" "github_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
