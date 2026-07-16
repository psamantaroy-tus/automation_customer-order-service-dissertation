# =============================================================================
# Full teardown — deletes EVERYTHING this project created (EKS, node group,
# RDS databases, ECR repos, security groups) so you can re-run the whole
# automated build from scratch and time it again.
#
# Run locally from the repo root:
#   ./scripts/destroy.ps1
#
# Requires: aws CLI configured, terraform, kubectl.
# =============================================================================
$ErrorActionPreference = "Stop"

$Region      = "eu-west-1"
$ClusterName = "dissertation-cluster"
$RepoRoot    = Split-Path -Parent $PSScriptRoot
$TfDir       = Join-Path $RepoRoot "terraform"

Write-Host "==> Getting the Terraform state bucket name..." -ForegroundColor Cyan
$AccountId = (aws sts get-caller-identity --query Account --output text)
$StateBucket = "tf-state-$AccountId-$Region"
Write-Host "    State bucket: $StateBucket"

# 1. Delete the LoadBalancer Service FIRST. This releases the AWS ELB and its
#    network interfaces; skipping it can block VPC/subnet cleanup later.
Write-Host "==> Deleting the order-service LoadBalancer (frees the ELB)..." -ForegroundColor Cyan
try {
  aws eks update-kubeconfig --name $ClusterName --region $Region
  kubectl delete svc order-service-svc --ignore-not-found=true
  Write-Host "    Waiting 30s for the ELB to be removed..."
  Start-Sleep -Seconds 30
} catch {
  Write-Host "    Cluster not reachable (already gone?) — continuing." -ForegroundColor Yellow
}

# 2. Terraform destroy — removes EKS, nodes, RDS, ECR, security groups, secrets.
Write-Host "==> Running terraform destroy (this takes ~15 minutes)..." -ForegroundColor Cyan
Push-Location $TfDir
try {
  terraform init `
    -backend-config="bucket=$StateBucket" `
    -backend-config="dynamodb_table=tf-locks"

  # Dummy DB passwords: destroy still requires the variables to be set, but
  # the values are irrelevant when tearing everything down.
  $env:TF_VAR_customer_db_password = "destroy-placeholder"
  $env:TF_VAR_order_db_password    = "destroy-placeholder"

  terraform destroy -auto-approve -input=false
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "TEARDOWN COMPLETE — EKS, RDS, and ECR removed." -ForegroundColor Green
Write-Host "The Terraform state bucket and OIDC role (bootstrap) are kept so you" -ForegroundColor Green
Write-Host "can immediately re-run the pipeline. To remove those too, run" -ForegroundColor Green
Write-Host "'terraform destroy' inside the bootstrap/ folder." -ForegroundColor Green
