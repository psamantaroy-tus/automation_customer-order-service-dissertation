terraform {
  required_version = ">= 1.5.0"

  # Remote state in S3 with DynamoDB locking (created by ../bootstrap).
  # `bucket` and `dynamodb_table` are supplied at init time via -backend-config
  # because the bucket name contains the account id. See terraform/README.md.
  backend "s3" {
    key     = "eks/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}
