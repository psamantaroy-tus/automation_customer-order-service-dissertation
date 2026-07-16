# =============================================================================
# ONE-OFF cleanup of the MANUALLY-created infrastructure (EKS cluster, node
# group, RDS databases, ECR repos, and the orphaned LoadBalancer) so that the
# Terraform pipeline can recreate everything from scratch.
#
# Safe to re-run: anything already gone is skipped with a warning.
#
# Run from the repo root:
#   ./scripts/cleanup-manual.ps1
# =============================================================================
$ErrorActionPreference = "Continue"

# Disable the AWS CLI pager so commands never pause with "-- More --".
$env:AWS_PAGER = ""

$Region      = "eu-west-1"
$ClusterName = "dissertation-cluster"

function Info($m) { Write-Host $m -ForegroundColor Cyan }
function Ok($m)   { Write-Host $m -ForegroundColor Green }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }

# --- 0. Delete the k8s LoadBalancer Service first (releases the AWS ELB) ------
Info "==> [0/4] Removing the order-service LoadBalancer (frees the ELB)..."
aws eks update-kubeconfig --name $ClusterName --region $Region 2>$null
if ($LASTEXITCODE -eq 0) {
  kubectl delete svc order-service-svc --ignore-not-found=true 2>$null
  Warn "    Waiting 30s for the ELB to be released..."
  Start-Sleep -Seconds 30
} else {
  Warn "    Cluster not reachable - skipping LB deletion."
}

# --- 1. Delete EKS node group(s), then the cluster ---------------------------
Info "==> [1/4] Deleting EKS node groups..."
$nodegroups = (aws eks list-nodegroups --cluster-name $ClusterName --region $Region --query "nodegroups" --output text 2>$null)
if ($LASTEXITCODE -eq 0 -and $nodegroups -and $nodegroups -ne "None") {
  foreach ($ng in ($nodegroups -split "\s+")) {
    if ([string]::IsNullOrWhiteSpace($ng)) { continue }
    Info "    Deleting node group: $ng"
    aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name $ng --region $Region 2>$null | Out-Null
    Warn "    Waiting for node group '$ng' to delete (3-5 min)..."
    aws eks wait nodegroup-deleted --cluster-name $ClusterName --nodegroup-name $ng --region $Region 2>$null
  }
  Ok "    Node groups deleted."
} else {
  Warn "    No node groups found (or cluster already gone)."
}

Info "==> [2/4] Deleting EKS cluster '$ClusterName'..."
aws eks describe-cluster --name $ClusterName --region $Region 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
  aws eks delete-cluster --name $ClusterName --region $Region 2>$null | Out-Null
  Warn "    Waiting for cluster to delete (5-10 min)..."
  aws eks wait cluster-deleted --name $ClusterName --region $Region 2>$null
  Ok "    Cluster deleted."
} else {
  Warn "    Cluster not found - skipping."
}

# --- 3. Delete the RDS databases --------------------------------------------
Info "==> [3/4] Deleting RDS databases..."
foreach ($db in @("customer-db", "order-db")) {
  aws rds describe-db-instances --db-instance-identifier $db --region $Region 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Info "    Deleting RDS instance: $db"
    aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot --delete-automated-backups --region $Region 2>$null | Out-Null
  } else {
    Warn "    RDS '$db' not found - skipping."
  }
}

# --- 4. Delete the ECR repositories -----------------------------------------
Info "==> [4/4] Deleting ECR repositories..."
foreach ($repo in @("customer-service", "order-service")) {
  aws ecr describe-repositories --repository-names $repo --region $Region 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Info "    Deleting ECR repo: $repo"
    aws ecr delete-repository --repository-name $repo --force --region $Region 2>$null | Out-Null
  } else {
    Warn "    ECR repo '$repo' not found - skipping."
  }
}

Write-Host ""
Ok "Deletion requests submitted. Now polling until everything is fully gone..."
Write-Host ""

# --- 5. Poll every 30s until all resources are actually gone -----------------
# EKS/ECR delete quickly, but RDS deletes in the background (~5 min); this loop
# waits for the slow ones so you know exactly when it is safe to re-run.

function Test-ResourceGone {
  param([string]$Kind, [string]$Name)
  switch ($Kind) {
    "eks" { aws eks describe-cluster --name $Name --region $Region 2>$null | Out-Null }
    "rds" { aws rds describe-db-instances --db-instance-identifier $Name --region $Region 2>$null | Out-Null }
    "ecr" { aws ecr describe-repositories --repository-names $Name --region $Region 2>$null | Out-Null }
  }
  return ($LASTEXITCODE -ne 0)
}

$checks = @(
  @{ Kind = "eks"; Name = $ClusterName },
  @{ Kind = "rds"; Name = "customer-db" },
  @{ Kind = "rds"; Name = "order-db" },
  @{ Kind = "ecr"; Name = "customer-service" },
  @{ Kind = "ecr"; Name = "order-service" }
)

$intervalSeconds = 30
$elapsed = 0
while ($true) {
  $remaining = @()
  foreach ($c in $checks) {
    if (-not (Test-ResourceGone -Kind $c.Kind -Name $c.Name)) {
      $remaining += ($c.Kind + ":" + $c.Name)
    }
  }

  if ($remaining.Count -eq 0) {
    Write-Host ""
    Ok "======================================================================"
    Ok " ALL MANUAL RESOURCES DELETED (checked after $elapsed s)."
    Ok " You can now RE-RUN the pipeline:"
    Ok "   GitHub -> Actions tab -> failed run -> 'Re-run all jobs'"
    Ok "======================================================================"
    for ($i = 0; $i -lt 3; $i++) { [console]::Beep(880, 250); Start-Sleep -Milliseconds 150 }
    break
  }

  Warn ("[" + $elapsed + "s] Still deleting: " + ($remaining -join ", "))
  Start-Sleep -Seconds $intervalSeconds
  $elapsed += $intervalSeconds
}
