# Terraform — EKS + RDS + ECR infrastructure

This recreates the entire manually-built AWS stack as code. It is normally run
by GitHub Actions, but you can run it locally too.

## Prerequisites
- Run `../bootstrap` once first (creates the S3 state bucket + OIDC role).
- AWS CLI configured (`aws configure`) or the GitHub Actions OIDC role.

## Initialise (remote backend)
The state bucket name contains your account id, so it is passed at init time:

```bash
terraform init \
  -backend-config="bucket=tf-state-<ACCOUNT_ID>-eu-west-1" \
  -backend-config="dynamodb_table=tf-locks"
```

## Apply
DB passwords are supplied as variables. Locally, export them:

```bash
export TF_VAR_customer_db_password='CustomerPass123!'
export TF_VAR_order_db_password='OrderPass123!'
terraform apply
```

In CI these come from the `CUSTOMER_DB_PASSWORD` / `ORDER_DB_PASSWORD` GitHub
secrets (as `TF_VAR_*` environment variables).

## Outputs
`terraform output` exposes the ECR URLs, RDS hostnames, and cluster name that
the deploy job injects into the Kubernetes manifests.

## Destroy
See `../scripts/destroy.ps1` — it deletes the LoadBalancer Service first, then
runs `terraform destroy`.
