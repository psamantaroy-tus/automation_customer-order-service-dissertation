# Terraform + GitHub Actions Automation Guide

Automates the entire AWS deployment that was previously done by hand in
`EKS_DEPLOYMENT_GUIDE.md`. One `git push` provisions all infrastructure with
Terraform, builds and pushes both Docker images, deploys to EKS, and smoke-tests
the live APIs. A teardown script removes everything so the cycle can be repeated
and timed — the whole point of the manual-vs-automated comparison.

> **The application code and APIs are unchanged.** This adds only infrastructure
> code (`terraform/`, `bootstrap/`), templated manifests (`k8s/`), two GitHub
> workflows, and helper scripts.

---

## What gets created

| Manual step (EKS_DEPLOYMENT_GUIDE) | Automated by |
|---|---|
| IAM roles (Stage 2) | `terraform/eks.tf` (EKS module manages roles) |
| ECR repos (Stage 3) | `terraform/ecr.tf` |
| Build & push images (Stage 4) | `deploy-eks.yml` build steps |
| RDS databases (Stage 5) | `terraform/rds.tf` |
| EKS cluster (Stage 6) | `terraform/eks.tf` |
| Node group (Stage 7) | `terraform/eks.tf` |
| Security group 3306 rule (Stage 8) | `terraform/rds.tf` |
| kubectl access fix (Stage 9) | `enable_cluster_creator_admin_permissions` |
| DB secrets (Stage 10) | `terraform/k8s.tf` |
| Deploy manifests (Stage 11) | `deploy-eks.yml` deploy steps |
| Verify (Stage 12) | `scripts/smoke-test.sh` |

---

## Repository layout

```
bootstrap/            # one-time: TF state backend + GitHub OIDC role
terraform/            # the full infra (ECR, EKS, RDS, security groups, secrets)
k8s/                  # templated manifests (__PLACEHOLDERS__ filled at deploy)
scripts/
  smoke-test.sh       # post-deploy end-to-end API test (used by CI)
  destroy.ps1         # local full teardown
.github/workflows/
  deploy-eks.yml      # push -> provision + deploy + test
  destroy.yml         # manual -> destroy everything
```

---

## One-time setup (do this once)

### Step 1 — Bootstrap AWS (local)

Creates the Terraform state backend and the GitHub OIDC role.

```bash
cd bootstrap
terraform init
terraform apply -var="github_repo=psamantaroy-tus/automation_customer-order-service-dissertation"
terraform output      # note these 4 values for Step 2
```

### Step 2 — Configure GitHub

1. **Settings → Actions → General** → Workflow permissions → **Read and write
   permissions** → Save.
2. **Settings → Secrets and variables → Actions → New repository secret** — add
   all five:

   | Secret | Value |
   |---|---|
   | `AWS_ROLE_ARN` | `aws_role_arn` output from Step 1 |
   | `AWS_REGION` | `eu-west-1` |
   | `TF_STATE_BUCKET` | `tf_state_bucket` output from Step 1 |
   | `CUSTOMER_DB_PASSWORD` | a password you choose |
   | `ORDER_DB_PASSWORD` | a password you choose |

That's it — no AWS access keys are ever stored in GitHub (OIDC issues
short-lived tokens per run).

---

## Running the automated deployment

Just push to `main` or `Automation`:

```bash
git add .
git commit -m "trigger deployment"
git push
```

Then open the repo's **Actions** tab → **Deploy to EKS (Terraform)** and watch:

1. **Terraform Apply** — creates/updates EKS, RDS, ECR, security groups, secrets.
2. **Build & push** — both images tagged with the commit SHA.
3. **Deploy** — renders manifests, `kubectl apply`, waits for rollouts.
4. **Smoke test** — creates a customer, creates an order, verifies the response.

A green run means the whole stack works end-to-end.

> **Timing note (for your comparison):** the **first** run takes ~15–20 minutes
> because EKS and RDS are created from scratch. Later runs (infra already up)
> finish in ~3–5 minutes — only build, deploy, and test run; Terraform is a no-op.

You can also trigger it manually: **Actions → Deploy to EKS → Run workflow**.

---

## Tearing everything down

To remove all infrastructure (so the next run rebuilds from zero):

### Option A — locally (Windows)
```powershell
./scripts/destroy.ps1
```

### Option B — from GitHub
**Actions → Destroy EKS Infrastructure → Run workflow**, type `DESTROY` to confirm.

Both delete the LoadBalancer first (releases the AWS ELB), then run
`terraform destroy` to remove EKS, the node group, both RDS databases, the ECR
repos, and the security groups. RDS uses `skip_final_snapshot` and ECR uses
`force_delete`, so teardown is clean and repeatable.

> The `bootstrap/` resources (state bucket + OIDC role) are intentionally kept
> so you can immediately re-run the pipeline. To remove those too:
> `cd bootstrap && terraform destroy`.

---

## The comparison loop

Repeat this to measure the automated path against the manual one:

```
git push            # ~15-20 min: full provision + deploy + test  (green = success)
./scripts/destroy.ps1   # ~15 min: tear it all down
# ...repeat as many times as you like
```

Every cycle is identical and hands-off — contrast with the multi-hour, click-by-click
manual process in `EKS_DEPLOYMENT_GUIDE.md`.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Error: configuring Terraform AWS Provider ... no valid credential` | OIDC role/trust wrong — re-check `AWS_ROLE_ARN` secret and the `github_repo` used in bootstrap. |
| `terraform init` backend error | `TF_STATE_BUCKET` secret missing or wrong; bootstrap not run. |
| Smoke test fails at "customer creation" | Pods not healthy — check `kubectl logs deployment/customer-service`; usually RDS security group or DB endpoint. |
| Rollout timeout | Image pull or DB connection issue — `kubectl describe pod <name>`. |
| First run very slow | Expected — EKS + RDS creation. Subsequent runs are fast. |
| Destroy stuck on VPC/subnet | LoadBalancer not deleted first — the scripts handle this; if run manually, `kubectl delete svc order-service-svc` then retry destroy. |
