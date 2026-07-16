# Reuse the account's default VPC and its subnets, exactly as the manual
# EKS build did — no new VPC is created.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_caller_identity" "current" {}
