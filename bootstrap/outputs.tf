# Copy these values into your GitHub repository secrets (Phase 0b).

output "tf_state_bucket" {
  description = "Set as GitHub secret TF_STATE_BUCKET"
  value       = aws_s3_bucket.tf_state.bucket
}

output "tf_lock_table" {
  description = "DynamoDB lock table name (referenced by terraform/backend.tf)"
  value       = aws_dynamodb_table.tf_locks.name
}

output "aws_role_arn" {
  description = "Set as GitHub secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "region" {
  description = "Set as GitHub secret AWS_REGION"
  value       = var.region
}
