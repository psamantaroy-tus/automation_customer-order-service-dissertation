# AWS EKS Deployment Guide
## customer-service & order-service — Complete Beginner-Friendly Documentation

---

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Stage 1 — Configure AWS CLI](#stage-1--configure-aws-cli)
4. [Stage 2 — Create IAM Roles](#stage-2--create-iam-roles)
5. [Stage 3 — Create ECR Repositories](#stage-3--create-ecr-repositories)
6. [Stage 4 — Build & Push Docker Images](#stage-4--build--push-docker-images)
7. [Stage 5 — Create RDS MySQL Databases](#stage-5--create-rds-mysql-databases)
8. [Stage 6 — Create EKS Cluster](#stage-6--create-eks-cluster)
9. [Stage 7 — Create Node Group](#stage-7--create-node-group)
10. [Stage 8 — Fix Security Groups](#stage-8--fix-security-groups)
11. [Stage 9 — Connect kubectl](#stage-9--connect-kubectl)
12. [Stage 10 — Create Kubernetes Secrets](#stage-10--create-kubernetes-secrets)
13. [Stage 11 — Update Manifests & Deploy](#stage-11--update-manifests--deploy)
14. [Stage 12 — Verify Deployment](#stage-12--verify-deployment)
15. [API Reference](#api-reference)
16. [How to Redeploy After Code Changes](#how-to-redeploy-after-code-changes)
17. [How to Stop AWS Services (Save Costs)](#how-to-stop-aws-services-save-costs)
18. [How to Start Services Again](#how-to-start-services-again)
19. [Troubleshooting](#troubleshooting)

---

## Overview

This project consists of two Spring Boot microservices deployed on AWS EKS (Kubernetes):

| Service | Port | Access | Description |
|---|---|---|---|
| customer-service | 8081 | Internal only | Manages customer data |
| order-service | 8082 | Public (LoadBalancer) | Manages orders, calls customer-service |

**Architecture:**
```
Internet → AWS Load Balancer → order-service (pod) → customer-service (pod)
                                      ↓                        ↓
                               RDS order_db            RDS customer_db
```

**Your AWS details (fill these in as you set them up):**
- AWS Account ID: `664858858732`
- Region: `eu-west-1` (Ireland)
- EKS Cluster: `dissertation-cluster`
- External URL: `a80af352e7286468c960dffb7cb87bb5-1513205418.eu-west-1.elb.amazonaws.com`

---

## Prerequisites

Before starting, make sure you have:
- **AWS Account** (paid account recommended — free tier has low EC2 quotas)
- **Docker Desktop** installed and running on your machine
- **AWS CLI** installed — verify with `aws --version` in PowerShell
- **kubectl** installed — verify with `kubectl version --client`

### Install kubectl (Windows)
```powershell
curl.exe -LO "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"
```
Move `kubectl.exe` to `C:\Windows\System32\`

---

## Stage 1 — Configure AWS CLI

The AWS CLI lets your terminal talk to your AWS account.

### Step 1: Create an IAM user for CLI access
1. Log into AWS Console → search **IAM** → click **IAM**
2. Left sidebar → **Users** → **Create user**
3. Username: `eks-deploy-user` → click **Next**
4. Select **Attach policies directly** → search and select **AdministratorAccess** → **Next**
5. Click **Create user**

### Step 2: Generate access keys
1. Click on `eks-deploy-user` → **Security credentials** tab
2. Scroll to **Access keys** → **Create access key**
3. Select **CLI** → **Next** → **Create access key**
4. Click **Download .csv file** — save this file safely, you cannot retrieve the secret key again

### Step 3: Configure CLI
Open PowerShell and run:
```powershell
aws configure
```
Enter when prompted:
- AWS Access Key ID: *(from CSV)*
- AWS Secret Access Key: *(from CSV)*
- Default region: `eu-west-1`
- Default output format: `json`

### Step 4: Verify
```powershell
aws sts get-caller-identity
```
You should see your Account ID in the output.

---

## Stage 2 — Create IAM Roles

IAM Roles give AWS services permission to talk to each other. You need two roles.

### Role 1: eks-cluster-role
This allows EKS to manage AWS resources on your behalf.

1. IAM → **Roles** → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: search **EKS** → select **EKS - Cluster** → **Next**
4. Policy `AmazonEKSClusterPolicy` is pre-selected — leave it → **Next**
5. Role name: `eks-cluster-role` → **Create role**

### Role 2: eks-nodegroup-role
This allows EC2 worker nodes to pull images and join the cluster.

1. IAM → **Roles** → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: **EC2** → **Next**
4. Search and tick each of these 3 policies:
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEC2ContainerRegistryReadOnly`
   - `AmazonEKS_CNI_Policy`
5. Role name: `eks-nodegroup-role` → **Create role**

---

## Stage 3 — Create ECR Repositories

ECR (Elastic Container Registry) stores your Docker images on AWS.

1. Search **ECR** in the console → **Elastic Container Registry**
2. Confirm region is **eu-west-1** (top-right corner)
3. Click **Create repository**
   - Visibility: **Private**
   - Name: `customer-service`
   - Click **Create repository**
4. Click **Create repository** again
   - Name: `order-service`
   - Click **Create repository**

After creation, click each repository and note the **URI**:
```
664858858732.dkr.ecr.eu-west-1.amazonaws.com/customer-service
664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service
```

---

## Stage 4 — Build & Push Docker Images

This stage builds your Spring Boot apps into Docker images and uploads them to ECR.

> **Important:** Docker Desktop must be running before these commands.

Open PowerShell and run each command one at a time:

### Authenticate Docker with ECR
```powershell
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 664858858732.dkr.ecr.eu-west-1.amazonaws.com
```
Expected output: `Login Succeeded`

### Navigate to project folder
```powershell
cd "C:\Users\priya\OneDrive\Desktop\automation_customer-order-service-dissertation"
```

### Build & push customer-service
```powershell
docker build -t customer-service ./customer-service
docker tag customer-service:latest 664858858732.dkr.ecr.eu-west-1.amazonaws.com/customer-service:latest
docker push 664858858732.dkr.ecr.eu-west-1.amazonaws.com/customer-service:latest
```

### Build & push order-service
```powershell
docker build -t order-service ./order-service
docker tag order-service:latest 664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service:latest
docker push 664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service:latest
```

Each build takes ~5 minutes. You will see layer-by-layer progress in the terminal.

---

## Stage 5 — Create RDS MySQL Databases

RDS provides managed MySQL databases. You create one per service.

### Database 1: customer-db

1. Search **RDS** → **Create database**
2. Method: **Full configuration create** (may also appear as Standard create)
3. Engine: **MySQL** → Version: **MySQL 8.0.x** (latest 8.0)
4. Template: **Dev/Test** (NOT Production — too expensive)
5. **Settings:**
   - DB instance identifier: `customer-db`
   - Master username: `admin`
   - Master password: *(choose a strong password and write it down)*
   - Confirm password: *(same)*
6. **Instance configuration:**
   - Click **Burstable classes (includes t classes)**
   - Select `db.t3.micro`
7. **Storage:**
   - 20 GiB, type gp2
   - Uncheck "Enable storage autoscaling"
8. **Connectivity:**
   - VPC: **default VPC**
   - Public access: **No**
   - VPC security group: **Create new** → name: `rds-customer-sg`
9. **Additional configuration** (scroll to bottom, expand this section):
   - Initial database name: `customer_db` ← **do not skip this**
10. Click **Create database** — takes 3–5 minutes

### Database 2: order-db

Repeat all steps above with:
- DB instance identifier: `order-db`
- Master password: *(different password, write it down)*
- VPC security group: **Create new** → name: `rds-order-sg`
- Initial database name: `order_db`

### Copy your endpoints

Once both show **Available** status, click each database → **Connectivity & security** tab → copy the **Endpoint**:
```
customer-db.cp8mqkw4aedt.eu-west-1.rds.amazonaws.com
order-db.cp8mqkw4aedt.eu-west-1.rds.amazonaws.com
```

---

## Stage 6 — Create EKS Cluster

EKS is AWS's managed Kubernetes service. The cluster is the control plane.

1. Search **EKS** → **Create cluster** → select **EKS**
2. Confirm region is **eu-west-1**

### Configure cluster
- Cluster name: `dissertation-cluster`
- Kubernetes version: leave default (latest shown)
- Cluster IAM role: select `eks-cluster-role`
- Click **Next**

### Specify networking
- VPC: select the **default VPC**
- Subnets: select **all available subnets** (tick all checkboxes)
- Security groups: leave blank
- Cluster endpoint access: **Public**
- Click **Next**

### Remaining steps
- Observability: leave defaults → **Next**
- Add-ons: leave pre-selected (CoreDNS, kube-proxy, VPC CNI) → **Next**
- Configure add-ons: leave defaults → **Next**
- Click **Create cluster**

> The cluster takes **10–15 minutes** to reach **Active** status. Wait before proceeding.

---

## Stage 7 — Create Node Group

Node groups are the EC2 instances that actually run your pods (containers).

Wait for `dissertation-cluster` to show **Active**, then:

1. Click `dissertation-cluster` → **Compute** tab → **Add node group**

### Configure node group
- Name: `dissertation-nodes`
- Node IAM role: `eks-nodegroup-role`
- Click **Next**

### Set compute and scaling
- AMI type: `Amazon Linux 2 (AL2_x86_64)`
- Capacity type: `On-Demand`
- Instance type: `t3.medium`
- Disk size: `20 GiB`
- Desired size: `2`
- Minimum size: `1`
- Maximum size: `2`
- Click **Next**

### Networking
- Subnets: select **all available subnets**
- Allow remote access: **off**
- Click **Next** → **Create**

Takes 3–5 minutes to show **Active**.

> **If node group fails with quota error:**
> Go to Service Quotas → Amazon EC2 → search "Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances" → request increase to 32.
> Then retry with Instance type `t3.small`, Desired size: `1`.

---

## Stage 8 — Fix Security Groups

> **This step is critical.** Without it, your pods cannot connect to RDS and will crash.

Your RDS databases sit inside a security group that blocks all traffic by default. You must add a rule to allow your EKS nodes to connect on port 3306 (MySQL).

### Step 1: Find the EKS node security group ID
1. Search **EC2** → **Instances** in the left sidebar
2. You will see your worker nodes listed
3. Click any node → scroll to **Security** tab
4. Copy the **Security group ID** (e.g. `sg-0a1d7f14162981f22`)

### Step 2: Add rule to rds-customer-sg
1. Search **VPC** → left sidebar → **Security groups**
2. Find and click `rds-customer-sg`
3. Click **Inbound rules** tab → **Edit inbound rules** → **Add rule**
   - Type: **MySQL/Aurora** (auto-sets port 3306)
   - Source: **Custom** → paste the EKS node security group ID
4. Click **Save rules**

### Step 3: Add rule to rds-order-sg
1. Click **Security groups** in the left sidebar again
2. Find and click `rds-order-sg`
3. Repeat the same inbound rule as above
4. Click **Save rules**

---

## Stage 9 — Connect kubectl

kubectl is the command-line tool for controlling Kubernetes clusters.

### Configure kubectl to talk to your EKS cluster
```powershell
aws eks update-kubeconfig --name dissertation-cluster --region eu-west-1
```

### Grant your IAM user access to the cluster
By default, only the AWS Console user who created the cluster has access.
To grant your CLI user (`eks-deploy-user`) access:

1. EKS → click `dissertation-cluster` → **Access** tab
2. Click **Create access entry**
3. IAM principal ARN: `arn:aws:iam::664858858732:user/eks-deploy-user`
4. Click **Next** → **Add access policy**
   - Policy: `AmazonEKSClusterAdminPolicy`
   - Access scope: **Cluster**
5. Click **Add policy** → **Next** → **Create**

### Verify connection
```powershell
kubectl get nodes
```
You should see your worker nodes with status **Ready**.

---

## Stage 10 — Create Kubernetes Secrets

Secrets store sensitive data (like passwords) securely in Kubernetes so they are not hardcoded in your manifest files.

```powershell
kubectl create secret generic customer-db-secret --from-literal=username=admin --from-literal=password=YOUR_CUSTOMER_DB_PASSWORD
```

```powershell
kubectl create secret generic order-db-secret --from-literal=username=admin --from-literal=password=YOUR_ORDER_DB_PASSWORD
```

Replace `YOUR_CUSTOMER_DB_PASSWORD` and `YOUR_ORDER_DB_PASSWORD` with the passwords you set in Stage 5.

Verify:
```powershell
kubectl get secrets
```

---

## Stage 11 — Update Manifests & Deploy

### Update customer-service/k8s/deployment.yaml

Open the file and make sure these values are set correctly:
```yaml
image: 664858858732.dkr.ecr.eu-west-1.amazonaws.com/customer-service:latest
imagePullPolicy: Always
# ...
value: "jdbc:mysql://customer-db.cp8mqkw4aedt.eu-west-1.rds.amazonaws.com:3306/customer_db?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"
```

### Update order-service/k8s/deployment.yaml

```yaml
image: 664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service:latest
imagePullPolicy: Always
# ...
value: "jdbc:mysql://order-db.cp8mqkw4aedt.eu-west-1.rds.amazonaws.com:3306/order_db?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"
```

### Apply all manifests
```powershell
kubectl apply -f customer-service/k8s/deployment.yaml
kubectl apply -f customer-service/k8s/service.yaml
kubectl apply -f order-service/k8s/deployment.yaml
kubectl apply -f order-service/k8s/service.yaml
```

---

## Stage 12 — Verify Deployment

### Check pods are running
```powershell
kubectl get pods
```
Both pods should show `1/1` under READY and `Running` status. Takes 1–2 minutes.

### Check services and get external URL
```powershell
kubectl get services
```
`order-service-svc` shows an `EXTERNAL-IP` — this is your public URL.

### Test health endpoint (in browser or Postman)
```
http://<EXTERNAL-IP>/actuator/health
```
Expected response: `{"status":"UP"}`

---

## API Reference

### Base URLs
| Service | Base URL |
|---|---|
| order-service (public) | `http://a80af352e7286468c960dffb7cb87bb5-1513205418.eu-west-1.elb.amazonaws.com` |
| customer-service (internal) | `http://localhost:8081` *(requires port-forward — see below)* |

### Access customer-service locally
Since customer-service is internal (ClusterIP), run this in a separate PowerShell terminal:
```powershell
kubectl port-forward svc/customer-service-svc 8081:8081
```
Leave this terminal open while testing customer-service endpoints.

---

### Customer Service Endpoints

#### Create a customer
```
POST http://localhost:8081/customer/createcustomer
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com"
}
```
Response: customer object with an `id` — **save this ID to create orders**

#### Get all customers
```
GET http://localhost:8081/customer/customers
```

#### Get customer by ID
```
GET http://localhost:8081/customer/{id}
```
Example: `http://localhost:8081/customer/1`

#### Delete a customer
```
DELETE http://localhost:8081/customer/delete/{id}
```

---

### Order Service Endpoints

#### Create an order for a customer
```
POST http://<EXTERNAL-IP>/order/create/{customerId}
Content-Type: application/json

{
  "orderDate": "2026-06-28",
  "amount": 99.99
}
```
Replace `{customerId}` with the ID returned when you created the customer.

#### Get all orders for a customer
```
GET http://<EXTERNAL-IP>/order/customer/{customerId}
```

#### Get all orders (paginated)
```
GET http://<EXTERNAL-IP>/order/allpaginatedorders?page=0&size=10
```

#### Update an order
```
PUT http://<EXTERNAL-IP>/order/{orderId}
Content-Type: application/json

{
  "orderDate": "2026-06-28",
  "amount": 149.99
}
```

#### Delete an order
```
DELETE http://<EXTERNAL-IP>/order/delete/{orderId}
```

#### Filter orders by date range
```
GET http://<EXTERNAL-IP>/order/filter?start=2026-01-01&end=2026-12-31
```

---

### Example Workflow: Create a customer then place an order

**Step 1:** Start port-forward for customer-service
```powershell
kubectl port-forward svc/customer-service-svc 8081:8081
```

**Step 2:** Create a customer
```powershell
curl -X POST http://localhost:8081/customer/createcustomer `
  -H "Content-Type: application/json" `
  -d '{"name": "Jane Smith", "email": "jane@example.com"}'
```
Note the `id` in the response (e.g. `1`).

**Step 3:** Create an order for that customer
```powershell
curl -X POST "http://a80af352e7286468c960dffb7cb87bb5-1513205418.eu-west-1.elb.amazonaws.com/order/create/1" `
  -H "Content-Type: application/json" `
  -d '{"orderDate": "2026-06-28", "amount": 99.99}'
```

**Step 4:** View the order
```powershell
curl "http://a80af352e7286468c960dffb7cb87bb5-1513205418.eu-west-1.elb.amazonaws.com/order/customer/1"
```

---

## How to Redeploy After Code Changes

When you change your Java code and want to push the update to EKS:

### Step 1: Rebuild and push the updated image

For customer-service changes:
```powershell
cd "C:\Users\priya\OneDrive\Desktop\automation_customer-order-service-dissertation"
docker build -t customer-service ./customer-service
docker tag customer-service:latest 664858858732.dkr.ecr.eu-west-1.amazonaws.com/customer-service:latest
docker push 664858858732.dkr.ecr.eu-west-1.amazonaws.com/customer-service:latest
```

For order-service changes:
```powershell
docker build -t order-service ./order-service
docker tag order-service:latest 664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service:latest
docker push 664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service:latest
```

### Step 2: Restart the deployment to pull the new image

```powershell
kubectl rollout restart deployment/customer-service
```
```powershell
kubectl rollout restart deployment/order-service
```

### Step 3: Watch the rollout
```powershell
kubectl rollout status deployment/customer-service
kubectl rollout status deployment/order-service
```

### Step 4: Verify pods are running the new version
```powershell
kubectl get pods
```
Both pods should return to `1/1 Running`.

> **Note:** Because `imagePullPolicy: Always` is set in the manifests, Kubernetes will always pull the latest image from ECR on every restart.

---

## How to Stop AWS Services (Save Costs)

When you are not actively using the deployment (e.g. overnight or between sessions), stop these services to avoid charges.

> **Estimated cost while running:** ~$5–8/day (EKS nodes + RDS + load balancer)
> **Estimated cost while stopped:** ~$0.50/day (EKS control plane only)

### Option A: Scale down pods only (cheapest, fastest)
This stops the pods but keeps the cluster and RDS running (RDS still charges).

```powershell
kubectl scale deployment customer-service --replicas=0
kubectl scale deployment order-service --replicas=0
```

### Option B: Scale down node group (stops EC2 charges)
1. AWS Console → **EKS** → `dissertation-cluster` → **Compute** tab
2. Click `dissertation-nodes` → **Edit**
3. Set Minimum size: `0`, Desired size: `0`
4. Click **Save**

This terminates all EC2 nodes. RDS still runs (small charge).

### Option C: Stop RDS instances (stops RDS charges too)
1. AWS Console → **RDS** → **Databases**
2. Click `customer-db` → **Actions** → **Stop temporarily**
   - AWS stops it for up to 7 days automatically
3. Repeat for `order-db`

> **Note:** RDS auto-restarts after 7 days. You will need to stop it again manually.

### Option D: Full stop (everything paused)
Do both Option B and Option C together for maximum savings.

---

## How to Start Services Again

### Step 1: Start RDS databases (if stopped)
1. AWS Console → **RDS** → **Databases**
2. Click `customer-db` → **Actions** → **Start**
3. Repeat for `order-db`
4. Wait for both to show **Available** (3–5 minutes)

### Step 2: Scale up node group (if scaled to 0)
1. **EKS** → `dissertation-cluster` → **Compute** tab
2. Click `dissertation-nodes` → **Edit**
3. Set Minimum size: `1`, Desired size: `2`
4. Click **Save**
5. Wait for nodes to show **Ready** (~3–5 minutes)

Verify nodes are ready:
```powershell
kubectl get nodes
```

### Step 3: Scale up pods (if scaled to 0)
```powershell
kubectl scale deployment customer-service --replicas=1
kubectl scale deployment order-service --replicas=1
```

### Step 4: Verify everything is running
```powershell
kubectl get pods
kubectl get services
```

Both pods should show `1/1 Running`. Your external URL remains the same.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Node group fails — "Fleet Requests" quota | EC2 vCPU quota too low | Service Quotas → increase "Running On-Demand Standard" to 32 |
| `kubectl get nodes` — credentials error | IAM user not added to cluster | EKS → Access tab → Create access entry with AmazonEKSClusterAdminPolicy |
| Pod in `CrashLoopBackOff` | DB connection refused | Check Stage 8 security groups; verify RDS endpoint in deployment.yaml |
| Pod in `ImagePullBackOff` | ECR URI wrong or Docker not authenticated | Re-run `docker login` command; verify image URI |
| `EXTERNAL-IP` stuck as `<pending>` | Load balancer still provisioning | Wait 3–5 minutes |
| `kubectl` — connection refused | kubeconfig not configured | Re-run `aws eks update-kubeconfig` |
| Pods stuck in `Pending` | Not enough node capacity | Check node group Desired size ≥ 2 |
| 404 on API call | Wrong URL path | Check API Reference section for correct paths |
| RDS connection timeout | Security group missing rule | Redo Stage 8 — add MySQL/3306 inbound rule from EKS node SG |

### View pod logs (most useful debugging tool)
```powershell
kubectl logs deployment/customer-service
kubectl logs deployment/order-service
```

### Describe a pod (shows events and errors)
```powershell
kubectl describe pod <pod-name>
```
Get pod name from `kubectl get pods`.

### Check environment variables inside a pod
```powershell
kubectl exec -it <pod-name> -- env | grep SPRING
```
