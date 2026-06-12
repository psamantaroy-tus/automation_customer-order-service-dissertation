# AWS EKS CI/CD Deployment Plan
## Customer Service + Order Service Microservices

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Target Architecture](#2-target-architecture)
3. [New Folder & File Structure](#3-new-folder--file-structure)
4. [Phase 1 — One-Time AWS Setup (Manual)](#4-phase-1--one-time-aws-setup-manual)
5. [Phase 2 — New Kubernetes Files](#5-phase-2--new-kubernetes-files)
6. [Phase 3 — Update Existing K8s Files](#6-phase-3--update-existing-k8s-files)
7. [Phase 4 — GitHub Actions CI/CD Workflow](#7-phase-4--github-actions-cicd-workflow)
8. [Phase 5 — Verification](#8-phase-5--verification)
9. [GitHub Secrets Reference](#9-github-secrets-reference)
10. [Cost & Further Considerations](#10-cost--further-considerations)

---

## 1. Project Overview

| Service | Port | Database | Communication |
|---|---|---|---|
| customer-service | 8081 | MySQL 8.0 (`customer_db`) | Receives HTTP calls |
| order-service | 8082 | MySQL 8.0 (`order_db`) | Calls customer-service via RestTemplate |

**Stack:** Spring Boot 4.0.2, Java 17, MySQL 8.0, Docker (multi-stage), Kubernetes

**Existing assets:**
- Multi-stage Dockerfiles for both services
- `docker-compose.yml` for local development
- Partial K8s manifests (app deployments + services only — no MySQL K8s manifests yet)
- Images currently referenced as `DOCKER_USERNAME/...` → needs to change to AWS ECR

---

## 2. Target Architecture

```
Developer pushes to GitHub (main branch)
        │
        ▼
┌──────────────────────────────────┐
│     GitHub Actions Pipeline      │
│                                  │
│  Job 1: Run Tests (Maven)        │
│  Job 2: Build & Push to ECR      │
│  Job 3: Deploy to EKS            │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────┐
│     AWS ECR (Container Registry) │
│  - customer-service:sha          │
│  - order-service:sha             │
└──────────┬───────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│               AWS EKS Cluster (Kubernetes)               │
│                                                          │
│  Namespace: microservices                                │
│                                                          │
│  ┌─────────────────────┐  ┌─────────────────────┐       │
│  │  customer-service   │  │   order-service     │       │
│  │  (Deployment)       │  │   (Deployment)      │       │
│  │  ClusterIP Service  │  │   LoadBalancer Svc  │       │
│  └────────┬────────────┘  └──────────┬──────────┘       │
│           │                          │                   │
│  ┌────────▼────────────┐  ┌──────────▼──────────┐       │
│  │  mysql-customer     │  │   mysql-order       │       │
│  │  (StatefulSet)      │  │   (StatefulSet)     │       │
│  │  EBS Volume (10Gi)  │  │   EBS Volume (10Gi) │       │
│  └─────────────────────┘  └─────────────────────┘       │
│                                                          │
│  ┌───────────────────────────────────────────────┐      │
│  │  NGINX Ingress Controller (AWS LoadBalancer)  │      │
│  │  /customer/* → customer-service-svc:8081      │      │
│  │  /order/*    → order-service-svc:8082         │      │
│  └───────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────┘
```

---

## 3. New Folder & File Structure

```
automation_customer-order-service-dissertation/
│
├── .github/
│   └── workflows/
│       ├── ci-cd.yml              ← NEW: Main pipeline (build → push → deploy)
│       └── destroy.yml            ← NEW: (optional) tear down cluster resources
│
├── k8s/                           ← NEW: shared cluster-level config
│   ├── namespace.yaml             ← NEW: creates "microservices" namespace
│   └── ingress.yaml               ← NEW: NGINX ingress routing rules
│
├── customer-service/
│   ├── Dockerfile                 ← unchanged
│   ├── pom.xml                    ← unchanged
│   ├── src/                       ← unchanged
│   └── k8s/
│       ├── deployment.yaml        ← UPDATE: image → ECR URL with $IMAGE_TAG
│       ├── service.yaml           ← unchanged (ClusterIP)
│       └── mysql/
│           ├── statefulset.yaml   ← NEW: MySQL StatefulSet + EBS volume
│           ├── service.yaml       ← NEW: ClusterIP for internal DNS
│           └── secret.yaml        ← NEW: template (real values from GitHub Secrets)
│
├── order-service/
│   ├── Dockerfile                 ← unchanged
│   ├── pom.xml                    ← unchanged
│   ├── src/                       ← unchanged
│   └── k8s/
│       ├── deployment.yaml        ← UPDATE: image → ECR URL with $IMAGE_TAG
│       ├── service.yaml           ← unchanged (LoadBalancer)
│       └── mysql/
│           ├── statefulset.yaml   ← NEW: MySQL StatefulSet + EBS volume
│           ├── service.yaml       ← NEW: ClusterIP for internal DNS
│           └── secret.yaml        ← NEW: template (real values from GitHub Secrets)
│
├── docker-compose.yml             ← unchanged (local dev only)
├── README.md                      ← UPDATE: add AWS/CI-CD setup docs
└── DEPLOYMENT_PLAN.md             ← this file
```

**Summary of changes:**
- 8 new files to create
- 2 existing K8s deployment files to update (image URLs)
- 0 Java source files change

---

## 4. Phase 1 — One-Time AWS Setup (Manual, ~30–45 min)

> Do these steps once before the CI/CD pipeline can work.

### Step 1: Create an AWS Account & IAM User

1. Go to [aws.amazon.com](https://aws.amazon.com) → create a free-tier account
2. In the AWS Console, go to **IAM** → **Users** → **Create user**
3. Name it `github-actions-user`, enable **programmatic access**
4. Attach these managed policies:
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEC2FullAccess`
   - `IAMFullAccess` *(needed by eksctl for node group roles)*
5. **Save the Access Key ID and Secret Access Key** — you only see them once

### Step 2: Create 2 ECR Repositories

1. AWS Console → **ECR** → **Create repository**
2. Create these two (keep them private):
   - `customer-service`
   - `order-service`
3. Note your **ECR Registry URL** — it looks like:
   `123456789012.dkr.ecr.us-east-1.amazonaws.com`

### Step 3: Install AWS CLI & eksctl on Your Machine

```bash
# Install AWS CLI (Windows)
winget install Amazon.AWSCLI

# Configure AWS CLI with your IAM credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (e.g. us-east-1), output format: json

# Install eksctl (Windows, using Chocolatey)
choco install eksctl

# Verify
eksctl version
```

### Step 4: Create an EKS Cluster

```bash
eksctl create cluster \
  --name microservices-cluster \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed
```

> This takes ~15 minutes. It creates the EKS control plane, worker nodes, VPC, and auto-configures `kubectl`.

Verify:
```bash
kubectl get nodes
# Should show 2 nodes in Ready state
```

### Step 5: Install NGINX Ingress Controller on EKS

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/aws/deploy.yaml

# Wait for it to get an external hostname (takes ~2 min)
kubectl get svc -n ingress-nginx
# Look for EXTERNAL-IP on ingress-nginx-controller — that is your public URL
```

### Step 6: Add GitHub Secrets

In your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add all secrets listed in [Section 9](#9-github-secrets-reference).

---

## 5. Phase 2 — New Kubernetes Files

### What each new file does

| File | What it does |
|---|---|
| `k8s/namespace.yaml` | Creates isolated `microservices` namespace so all resources are grouped |
| `k8s/ingress.yaml` | Routes external traffic: `/customer/*` and `/order/*` to the right service |
| `customer-service/k8s/mysql/statefulset.yaml` | Runs MySQL as a stable pod with a persistent EBS disk |
| `customer-service/k8s/mysql/service.yaml` | Gives MySQL a stable DNS name (`mysql-customer-svc`) inside the cluster |
| `customer-service/k8s/mysql/secret.yaml` | Template file — holds base64 DB credentials structure (real values injected by CI/CD) |
| `order-service/k8s/mysql/statefulset.yaml` | Same as above for order-service MySQL |
| `order-service/k8s/mysql/service.yaml` | Gives order MySQL the DNS name `mysql-order-svc` |
| `order-service/k8s/mysql/secret.yaml` | Template for order DB credentials |

### Why StatefulSet for MySQL (not Deployment)?

- **Deployments** are for stateless apps — pods can be replaced freely
- **StatefulSets** guarantee:
  - Stable pod name (`mysql-customer-0`) — won't change on restart
  - Persistent volume claim survives pod restarts (your data is not lost)
  - Ordered startup/shutdown (safe for databases)

---

## 6. Phase 3 — Update Existing K8s Files

Two files need their `image:` field updated to use ECR instead of Docker Hub:

**`customer-service/k8s/deployment.yaml`** — change:
```yaml
# Before
image: DOCKER_USERNAME/customer-service:latest

# After
image: ${ECR_REGISTRY}/customer-service:${IMAGE_TAG}
```

**`order-service/k8s/deployment.yaml`** — change:
```yaml
# Before
image: DOCKER_USERNAME/order-service:latest

# After
image: ${ECR_REGISTRY}/order-service:${IMAGE_TAG}
```

The CI/CD pipeline uses `envsubst` to replace `${ECR_REGISTRY}` and `${IMAGE_TAG}` with real values before applying to Kubernetes.

---

## 7. Phase 4 — GitHub Actions CI/CD Workflow

File: `.github/workflows/ci-cd.yml`

**Trigger:** Push to `main` branch (or `dissertation` — confirm which you use)

```
┌─────────────────────────────────────────────────────────┐
│ Job 1: test                                             │
│   - Checkout code                                       │
│   - Set up Java 17                                      │
│   - Run: mvn test (customer-service)                    │
│   - Run: mvn test (order-service)                       │
│   Result: fails fast if any test breaks                 │
└────────────────────┬────────────────────────────────────┘
                     │ runs only if test passes
┌────────────────────▼────────────────────────────────────┐
│ Job 2: build-and-push                                   │
│   - Configure AWS credentials (from GitHub Secrets)     │
│   - Login to ECR                                        │
│   - Docker build customer-service → tag with git SHA    │
│   - Docker push to ECR                                  │
│   - Docker build order-service → tag with git SHA       │
│   - Docker push to ECR                                  │
│   Result: both images available in ECR                  │
└────────────────────┬────────────────────────────────────┘
                     │ runs only if build passes
┌────────────────────▼────────────────────────────────────┐
│ Job 3: deploy                                           │
│   - Configure AWS credentials                           │
│   - Update kubeconfig (connect kubectl to EKS)          │
│   - Apply namespace.yaml                                │
│   - Create K8s Secrets from GitHub Secrets (kubectl)    │
│   - Apply MySQL StatefulSets + Services                 │
│   - Wait for MySQL pods to be Ready                     │
│   - Substitute image tags in deployment.yaml (envsubst) │
│   - Apply app deployments + services                    │
│   - Apply ingress.yaml                                  │
│   - kubectl rollout status (verify both deployments)    │
│   Result: live services on EKS                          │
└─────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- **Image tag = `$GITHUB_SHA`** (the commit hash) — every deployment is unique and fully traceable. Rolling back = redeploying with an older SHA.
- **Secrets never in the repo** — real passwords only live in GitHub Secrets, injected at deploy time via `kubectl create secret`
- **MySQL applies before apps** — ordering ensures databases are ready before Spring Boot starts connecting
- **`kubectl rollout status`** at the end — the pipeline fails if pods don't become healthy, giving you immediate feedback

---

## 8. Phase 5 — Verification

After the GitHub Actions workflow shows all green:

```bash
# Connect to your cluster
aws eks update-kubeconfig --name microservices-cluster --region us-east-1

# Check all pods are Running
kubectl get pods -n microservices

# Expected output:
# customer-service-xxx-xxx     1/1  Running
# order-service-xxx-xxx        1/1  Running
# mysql-customer-0             1/1  Running
# mysql-order-0                1/1  Running

# Get your public Ingress URL
kubectl get ingress -n microservices
# Note the ADDRESS field — this is your public hostname

# Test endpoints
curl http://<INGRESS_ADDRESS>/customer/customers
curl http://<INGRESS_ADDRESS>/order/allpaginatedorders

# Check logs if something is wrong
kubectl logs <pod-name> -n microservices
kubectl describe pod <pod-name> -n microservices
```

---

## 9. GitHub Secrets Reference

| Secret Name | Description | Example Value |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key | `wJalrXUtnFEMI/K7MDENG/...` |
| `AWS_REGION` | AWS region for your cluster | `us-east-1` |
| `ECR_REGISTRY` | ECR registry URL (no repo name) | `123456789012.dkr.ecr.us-east-1.amazonaws.com` |
| `EKS_CLUSTER_NAME` | Name of your EKS cluster | `microservices-cluster` |
| `MYSQL_ROOT_PASSWORD` | MySQL root password for both DBs | `StrongP@ss123!` |
| `CUSTOMER_DB_PASSWORD` | Password for customer_db user | `CustomerP@ss!` |
| `ORDER_DB_PASSWORD` | Password for order_db user | `OrderP@ss!` |

> **Never commit real passwords to the repository.** The `secret.yaml` files in the repo are templates only.

---

## 10. Cost & Further Considerations

### AWS Cost Estimate

| Resource | Cost |
|---|---|
| EKS Control Plane | ~$0.10/hour (~$73/month) |
| 2x t3.medium nodes | ~$0.0416/hour each (~$60/month total) |
| EBS volumes (2x 10Gi) | ~$2/month |
| ECR storage | ~$0.10/GB/month (negligible) |
| **Total (running 24/7)** | **~$135/month** |

> **Tip for dissertation:** Stop the node group when not testing to save money:
> ```bash
> eksctl scale nodegroup --cluster=microservices-cluster --nodes=0 --name=workers
> # Restart when needed:
> eksctl scale nodegroup --cluster=microservices-cluster --nodes=2 --name=workers
> ```
> Or delete the cluster entirely and recreate it when needed.

### SonarCloud Integration (Optional)

If needed for grading, add a 4th parallel job in the CI/CD pipeline:
1. Create account at [sonarcloud.io](https://sonarcloud.io) → link GitHub repo
2. Add `SONAR_TOKEN` to GitHub Secrets
3. Add `sonar:sonar` goal to the Maven test step

### Branch Configuration

The README mentions branch `dissertation`. Confirm whether to trigger CI/CD on:
- `main` — standard production practice
- `dissertation` — matches existing README convention

Update the `on: push: branches:` section in `ci-cd.yml` accordingly.

### Rollback Strategy

Since images are tagged with the git SHA, rolling back is:
```bash
# Find the previous working commit SHA from git log or GitHub Actions history
kubectl set image deployment/customer-service \
  customer-service=<ECR_REGISTRY>/customer-service:<PREVIOUS_SHA> \
  -n microservices
```
