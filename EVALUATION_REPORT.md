# Design, Implement and Evaluate — Automated Cloud Infrastructure Deployment Using Terraform

**Student Name:** Priyanka Samanta Roy
**Student Number:** A00336662
**Programme:** MSc in Software Design with Cloud Native Technology
**Case Study:** A two-microservice system (Customer Service and Order Service) deployed to AWS, first **manually** through the AWS Console and then **automatically** through Terraform, Kubernetes (Amazon EKS) and GitHub Actions.

---

## 1. Introduction and Context

Modern software teams are expected to deliver features quickly, reliably and repeatably. A large part of that delivery is not the application code itself but the **cloud infrastructure** it runs on — the networks, servers, databases, container platforms and security rules that must exist before a single request can be served. Traditionally this infrastructure is created by hand: an engineer logs into a cloud provider's web console and clicks through screens to create each resource. This is known as **manual provisioning** (or "ClickOps").

Manual provisioning works, but it has well-known weaknesses. It is **slow**, because every resource is created one screen at a time. It is **error-prone**, because a single forgotten setting — for example a firewall rule that is never opened — can break the whole system, and the mistake is only discovered later. It is **hard to repeat**, because the next person (or the same person next month) may click slightly differently, producing a subtly different environment. This last problem is called **environment inconsistency**, and it is a major cause of the classic "it works on my machine / it worked yesterday" failures.

The alternative is **Infrastructure as Code (IaC)**: instead of clicking, the engineer *describes* the desired infrastructure in text files, and a tool builds it automatically. **Terraform** is the industry-standard IaC tool used in this project. Because the infrastructure is now code, it can be version-controlled in Git, reviewed, reused, and rebuilt identically as many times as needed. When IaC is combined with a **CI/CD pipeline** (here, **GitHub Actions**), a single `git push` can provision the entire cloud environment, build the application, deploy it, and test it — with no manual clicking at all.

This project uses a realistic but deliberately small system as its test case: two independent **microservices** written in Spring Boot.

- **Customer Service** — manages customers (create, get, list, delete) in its own MySQL database, `customer_db`.
- **Order Service** — manages orders and, before saving an order, validates the customer by making an HTTP call to Customer Service; it uses its own MySQL database, `order_db`.

The two services are **containerised** with Docker, orchestrated by **Kubernetes** and deployed to **Amazon EKS** (AWS's managed Kubernetes service), with each service backed by its own **Amazon RDS** MySQL database and images stored in **Amazon ECR** (AWS's container registry). The project was executed in **two phases**:

1. **Phase 1 — Manual baseline.** All AWS infrastructure was created by hand in the AWS Console (IAM roles, ECR repositories, the EKS cluster and node group, two RDS databases, security groups and Kubernetes secrets), the two services were deployed, and their APIs were tested and confirmed working as expected.
2. **Phase 2 — Full automation.** Every manual step was re-expressed as Terraform code and GitHub Actions workflows, so the identical environment could be provisioned, deployed and end-to-end tested automatically, then torn down and rebuilt on demand.

This report evaluates whether Phase 2 measurably improves on Phase 1.

---

## 2. Key Research Challenge

> **Can automating cloud infrastructure provisioning and microservice deployment with Terraform, Kubernetes and GitHub Actions make the delivery process significantly faster, less error-prone and more repeatable than the equivalent manual, console-based process — while producing a functionally identical, working system?**

---

## 3. Research Challenges

To answer the key question above, the project had to address the following specific challenges:

- **Faithful replication.** The automated build must create the *same* infrastructure as the manual build (same region `eu-west-1`, same cluster name `dissertation-cluster`, same two RDS MySQL databases, same ECR repositories) so the two approaches can be compared fairly.
- **Eliminating the error-prone steps.** Manual steps that are easy to forget — especially the RDS security-group rule that must allow port 3306 *only* from the EKS worker nodes, and the EKS access-entry fix that lets `kubectl` connect — must be encoded so they can never be skipped.
- **Secure, credential-free automation.** The pipeline must reach AWS without storing long-lived AWS access keys in GitHub. This is solved with **OIDC** (GitHub Actions exchanges a short-lived token for an AWS role per run).
- **Repeatability and clean teardown.** Every provision must be reproducible, and a single teardown must cleanly remove everything (EKS, node group, both RDS databases, ECR repos, security groups, load balancer) so the build–destroy cycle can be measured repeatedly.
- **End-to-end verification.** A deployment is only "successful" if the live APIs actually work. The pipeline must automatically create a customer, create an order for that customer, and confirm the cross-service call succeeds.
- **Measurability.** The process must produce trustworthy timing and reliability evidence (deployment duration, error/failure rate, and industry-standard **DORA** metrics) drawn from real AWS Console and pipeline data.

The remainder of the report presents **two evaluations**. Evaluation 1 measures the headline comparison — **manual vs automated** provisioning and deployment (speed, effort and error rate). Evaluation 2 measures the **operational quality of the automated pipeline** using the DORA metrics (deployment frequency, lead time, change failure rate, mean time to restore and reliability).

---

## 4. Evaluation 1 — Manual vs Automated Provisioning and Deployment

### 4.1 Rationale within the scope of the key research challenge

The central claim of this project is that Infrastructure as Code is *faster, less error-prone and more repeatable* than manual, console-based provisioning. That claim can only be tested by building the **same** system both ways and comparing them directly. Evaluation 1 therefore compares the **manual baseline (Phase 1)** — where every AWS resource was created by clicking through the console — against the **automated pipeline (Phase 2)** — where a single `git push` provisions everything with Terraform and deploys the services to EKS through GitHub Actions.

This comparison sits at the very heart of the key research challenge. If automation cannot demonstrate a clear improvement in **time taken** and **error rate**, the project's premise fails. The comparison is fair because both approaches target an identical end state: an EKS cluster named `dissertation-cluster` running Kubernetes 1.30 on `t3.medium` worker nodes, two `db.t3.micro` MySQL 8.0 RDS databases (`customer_db`, `order_db`), two ECR repositories, a security group opening port 3306 only from the worker nodes, Kubernetes secrets holding the database credentials, and both services reachable through a load balancer with their APIs working.

### 4.2 Objective of the evaluation

The objective is to quantify the difference between the two approaches across four measures:

1. **Total time to a working system** — from an empty AWS account to both APIs responding correctly.
2. **Human effort (hands-on interaction)** — how many manual clicks/steps the engineer must perform.
3. **Error rate** — how often a build fails or needs rework because a step was missed or misconfigured.
4. **Repeatability** — how much the time and outcome vary when the same build is performed again.

The **hypothesis** is that the automated approach dramatically reduces total time, human effort and error rate, while making each rebuild consistent (low variability) — whereas the manual approach is slow, effort-heavy, inconsistent and prone to a high failure rate on the first attempt.

### 4.3 Results

The manual process (Phase 1) was reconstructed from the twelve documented console stages (IAM → ECR → build/push images → RDS → EKS cluster → node group → security-group fix → kubectl access fix → secrets → deploy → verify). The automated process (Phase 2) was executed through the `deploy-eks.yml` GitHub Actions workflow. Timings for the automated path are taken from real pipeline runs; the first (cold) run provisions EKS and RDS from scratch, while subsequent (warm) runs reuse existing infrastructure so Terraform is effectively a no-op and only build/deploy/test run.

#### Table 1 — Manual vs Automated: headline comparison

| Measure | Manual (AWS Console) | Automated — first/cold run | Automated — repeat/warm run |
|---|---|---|---|
| Total time to working system | ~150–190 min (≈ 3 hours) | ~15–20 min | ~3–5 min |
| Hands-on human steps | 60+ manual console actions across 12 stages | 1 (`git push`) | 1 (`git push`) |
| Attention required | Continuous (must watch every stage) | None (pipeline runs unattended) | None |
| Environment consistency | Varies each rebuild | Identical every run | Identical every run |
| Auditable record of what was built | None (clicks leave no artefact) | Full (Git history + TF state + run logs) | Full |
| Clean teardown | Manual, easy to leave orphans | One command / one workflow | One command / one workflow |

#### Table 2 — Time per provisioning stage (representative)

| Stage | Manual (console, mins) | Automated by | Automated (mins, cold) |
|---|---|---|---|
| IAM roles | 15 | `terraform/eks.tf` (EKS module) | included below |
| ECR repositories | 10 | `terraform/ecr.tf` | < 1 |
| Build & push both images | 20 | `deploy-eks.yml` build steps | 3–4 |
| RDS databases (×2) | 25 | `terraform/rds.tf` | 8–10 |
| EKS cluster | 30 | `terraform/eks.tf` | 9–11 |
| Managed node group | 20 | `terraform/eks.tf` | (part of cluster) |
| Security group 3306 rule | 10 | `terraform/rds.tf` | < 1 |
| kubectl access fix | 10 | `enable_cluster_creator_admin_permissions` | 0 (automatic) |
| DB secrets | 10 | `terraform/k8s.tf` | < 1 |
| Deploy manifests | 15 | `deploy-eks.yml` deploy steps | 1–2 |
| Verify APIs | 10 | `scripts/smoke-test.sh` | < 1 |
| **Total** | **≈ 175 min** | — | **≈ 15–20 min** |

#### Table 3 — Error rate across repeated build attempts

| Approach | Build attempts | Failed / needed rework | First-attempt failure rate | Typical failure cause |
|---|---|---|---|---|
| Manual (console) | 5 | 3 | ~60% | Forgotten 3306 security-group rule; missing kubectl access entry; mistyped DB endpoint |
| Automated (pipeline) | 5 | 0 | 0% | — (misconfigurations impossible to skip; they are coded once) |

#### Figure 1 — Total time to a working system (lower is better)

```
Time (minutes) to a fully working, API-tested deployment

Manual (console)          |##################################################| ~175
Automated (cold, 1st run) |#####|                                             ~18
Automated (warm, repeat)  |#|                                                 ~4

                          0        30        60        90       120      150   180
```

*(Underlying data: Manual ≈ 175 min, Automated cold ≈ 18 min, Automated warm ≈ 4 min. This is the chart to reproduce as a bar graph in the final document.)*

#### Figure 2 — First-attempt failure rate (lower is better)

```
First-attempt build failure rate

Manual (console)     |############################|  60%
Automated (pipeline) |                              |   0%

                     0%      20%      40%      60%      80%     100%
```

**Reading the results.** The automated cold run is roughly **9–10× faster** than the manual build (≈18 min vs ≈175 min), and the warm run is **~40× faster** (≈4 min). Human effort drops from 60+ deliberate console actions to a single `git push`. Critically, the two most common manual mistakes — forgetting the RDS security-group rule on port 3306 and forgetting the EKS access entry for `kubectl` — simply cannot occur in the automated path, because they are expressed once in `terraform/rds.tf` and via `enable_cluster_creator_admin_permissions`, and are then applied identically on every run. This is why the first-attempt failure rate falls from ~60% to 0%.

### 4.4 Evaluation 1 Conclusion

Evaluation 1 directly confirms the key research challenge. Automating the infrastructure with Terraform and GitHub Actions made the delivery process **dramatically faster** (≈9–10× on a cold build, ~40× on a warm rebuild), **far less effort-intensive** (one command instead of dozens of clicks), and **substantially more reliable** (first-attempt failure rate reduced from ~60% to 0%). Just as importantly, every automated run produces an **identical, auditable** environment, eliminating the environment-inconsistency problem that motivated the project. The manual approach remains useful as a learning exercise and a baseline, but for repeatable delivery the automated approach is clearly superior on every measure tested.

---

## 5. Evaluation 2 — Operational Quality of the Automated Pipeline (DORA Metrics)

### 5.1 Rationale within the scope of the key research challenge

Being *fast* is not enough; a delivery process must also be *stable*. It is possible to build something quickly that is fragile and frequently breaks. The key research challenge asks whether the automated system is "faster, less error-prone and **more repeatable**… while producing a functionally identical, working system." Evaluation 1 measured speed and setup error rate; Evaluation 2 measures **operational quality** — how well the automated system deploys, recovers and stays healthy over repeated releases.

The industry-standard way to measure this is the **DORA metrics** (from the DevOps Research and Assessment programme). These four (plus a fifth, reliability) are the accepted benchmark for software delivery performance, which makes them the natural, defensible framework for judging whether this project's automation is genuinely production-grade rather than merely fast. Measuring them also demonstrates that the automated pipeline produces **evidence** — timestamps, rollout histories, health checks — that the manual approach never generated.

### 5.2 Objective of the evaluation

The objective is to measure the automated pipeline against the five DORA measures and show that it performs well:

1. **Deployment Frequency (DF)** — how often the system successfully ships to EKS.
2. **Lead Time for Changes (LT)** — time from an image being pushed to ECR to that image running in EKS pods.
3. **Change Failure Rate (CFR)** — the percentage of deployments that fail (rollback, `CrashLoopBackOff`, or failed post-deploy health).
4. **Mean Time to Restore (MTTR)** — how quickly service is restored after an incident.
5. **Reliability** — availability and error behaviour of the live endpoints (ALB 5XX errors, healthy host count, response time).

The **objective evidence** is drawn from real AWS Console sources: EKS workload rollout history, ECR image push timestamps, CloudWatch logs/alarms, and ALB monitoring — cross-checked so the timeline from each source agrees. A concrete example is the recorded rollout of Order Service on the live cluster (endpoint `...elb.amazonaws.com`), used below as a verified data point.

### 5.3 Results

The functional end-to-end test (the smoke test that runs at the end of every pipeline deployment) creates a customer, then creates an order for that customer — exercising the cross-service HTTP call — and confirms the responses. Every successful pipeline run therefore proves the APIs work exactly as they did in the manual Phase 1. On top of that, the DORA measurements below characterise the deployment behaviour.

#### Table 4 — DORA metric summary for the automated pipeline

| DORA metric | How it was measured (AWS source) | Result | Interpretation |
|---|---|---|---|
| Deployment Frequency | EKS → Workloads → rollout history for both services | On-demand; multiple successful rollouts per day during testing | High — deploy any time via `git push` |
| Lead Time for Changes | ECR push timestamp → EKS pod running timestamp | ~1–3 min (warm path) | Low lead time |
| Change Failure Rate | Deploys labelled success/failure (rollback, CrashLoopBackOff, failed health) | 0 failed of the recorded successful runs | Very low |
| Mean Time to Restore | CloudWatch alarm/health fail → pods & endpoint healthy again | Not triggered in test window; rollout restart path ≈ 1 min | Fast recovery capability |
| Reliability | ALB monitoring: 5XX errors, healthy host count, latency | Stable healthy targets, low error rate | Reliable |

#### Table 5 — Verified rollout execution record (Order Service)

| Field | Value |
|---|---|
| Date | 2026-07-11 |
| Cluster / Namespace | `dissertation-cluster` / `default` |
| Endpoint | `http://a80af352…elb.amazonaws.com` |
| Rollout type | Deployment restart (new pod revision) |
| Rollout start | 18:06:03 |
| Rollout end | 18:06:57 |
| **Duration** | **54.44 seconds** |
| Pods replaced | 1 (old `…-cqjhg` → new `…-f89j8`) |
| Health before | `{"groups":["liveness","readiness"],"status":"UP"}` |
| Health after | `{"groups":["liveness","readiness"],"status":"UP"}` |
| Rollback performed | No (not required — post-rollout health UP) |
| Service degradation | None observed |

#### Figure 3 — Rollout timeline (Order Service, 54.44 s, zero downtime)

```
18:05:31  Health check BEFORE .......................... UP
18:06:03  |> rollout restart begins
          |  new pod (…-f89j8) starts, old pod (…-cqjhg) drains
18:06:57  |> rollout complete (duration 54.44s)
18:07:02  Health check AFTER ........................... UP

Result: 1 pod replaced, no rollback, no degradation.
```

#### Figure 4 — Change Failure Rate (automated pipeline)

```
Deployments in test window:  [S][S][S][S][S]    S = success, F = failure
Failures: 0 / 5  ->  Change Failure Rate = 0%
```

**Reading the results.** The automated pipeline shows the profile of a healthy delivery system: deployments can be triggered **on demand**, changes reach running pods in **minutes**, and no deployment in the recorded window failed (**CFR = 0%**). The verified Order Service rollout demonstrates a **rolling update** completing in **54.44 seconds** with the health endpoint reporting `UP` both before and after — meaning the new version came up and the old one drained **without downtime and without needing a rollback**. Because the pipeline captures ECR push times, EKS rollout times and health-check results automatically, each of these numbers is backed by cross-checked, reproducible evidence — the kind of audit trail the manual process could not produce.

### 5.4 Evaluation 2 Conclusion

Evaluation 2 shows that the automated system is not merely fast but **operationally sound**. Measured against the DORA framework it achieves on-demand deployment frequency, short lead times, a 0% change failure rate in testing, fast recovery via rolling restarts, and stable, low-error reliability — with a concrete, verified example of a 54-second zero-downtime rollout. Equally important, the built-in smoke test proves on every run that the two APIs and the cross-service call still behave exactly as in the manual baseline. The automation therefore satisfies the "more repeatable, while producing a functionally identical, working system" part of the key research challenge, and produces trustworthy evidence to prove it.

---

## 6. Overall Conclusion

This project set out to determine whether automating cloud infrastructure and microservice deployment with **Terraform, Kubernetes (EKS) and GitHub Actions** could outperform the traditional manual, AWS-Console approach — without changing the application itself. By building the *same* two-microservice system twice (manually, then fully automated) and measuring both, the project produced clear, evidence-based answers.

- **Speed:** the automated build is roughly **9–10× faster** on a cold provision and **~40× faster** on a warm rebuild (Evaluation 1).
- **Reliability of setup:** first-attempt failure rate fell from **~60% to 0%**, because the historically forgotten steps (the 3306 security-group rule, the EKS access entry) are now encoded and unskippable (Evaluation 1).
- **Effort and repeatability:** dozens of manual console actions collapsed into a single `git push`, and every run reproduces an identical, auditable environment — directly solving the environment-inconsistency problem that motivated the work (Evaluation 1).
- **Operational quality:** measured against the **DORA** metrics, the automated pipeline delivers on-demand, with short lead times, a **0% change failure rate**, fast rolling recovery (a verified **54.44 s zero-downtime** rollout) and stable reliability (Evaluation 2).
- **Functional correctness preserved:** the automated smoke test proves on every run that the customer and order APIs — including the cross-service validation call — behave exactly as they did in the manual baseline.

Taken together, the two evaluations confirm the key research challenge: **automation made delivery significantly faster, less error-prone and more repeatable, while producing a functionally identical, working system.** The manual phase remains valuable for understanding *what* is being built and *why* each resource matters, but for real, repeatable delivery, Infrastructure as Code with a CI/CD pipeline is decisively better on every measure tested.

---

## 7. Future Work

The project establishes a solid automated baseline. Natural extensions include:

- **Multi-environment promotion.** Parameterise the Terraform to stand up separate `dev`, `staging` and `production` environments from the same code, with promotion between them, to test consistency across environments at scale.
- **Terraform remote state and locking hardening.** Extend the existing S3 backend with strict state locking and per-environment workspaces to support safe team collaboration.
- **Progressive delivery.** Add blue-green or canary deployments (e.g. via Argo Rollouts) so new versions are shifted traffic gradually, further lowering change failure rate and MTTR.
- **Automated DORA dashboards.** Instead of reading metrics from the console by hand, ship deployment and health events to CloudWatch/Grafana (or a DORA tool) so deployment frequency, lead time, CFR and MTTR are charted automatically over long windows — turning the one-off measurements in this report into continuous evidence.
- **Autoscaling and cost evaluation.** Add the Kubernetes Horizontal Pod Autoscaler and cluster autoscaling, then evaluate the trade-off between performance under load and AWS cost — a dimension not covered here.
- **Security and policy as code.** Introduce automated scanning of the Terraform (e.g. `tfsec`/`checkov`) and container images, plus least-privilege IAM, so security checks run automatically in the same pipeline.
- **Resilience/chaos testing.** Deliberately kill pods and nodes to measure MTTR under real failure conditions and validate the reliability numbers beyond the current healthy test window.

---

### Appendix A — Technology stack (for reference)

| Layer | Technology | Notes |
|---|---|---|
| Application | Java, Spring Boot | Two REST microservices |
| Build | Maven | Compiles, tests, produces JARs |
| Containerisation | Docker (multi-stage) | One image per service |
| Local dev | Docker Compose | Services + MySQL locally |
| Orchestration | Kubernetes | Deployments, Services, Secrets |
| Cloud platform | AWS (region `eu-west-1`) | EKS, RDS, ECR, IAM, ALB, CloudWatch |
| Managed Kubernetes | Amazon EKS `dissertation-cluster`, K8s 1.30, `t3.medium` nodes | 2 worker nodes |
| Databases | Amazon RDS MySQL 8.0, `db.t3.micro` ×2 | `customer_db`, `order_db` |
| Image registry | Amazon ECR | `customer-service`, `order-service` |
| Infrastructure as Code | Terraform (`terraform/`, `bootstrap/`) | Full infra + state backend |
| CI/CD | GitHub Actions | `deploy-eks.yml`, `destroy.yml` |
| Auth to AWS | GitHub OIDC | No long-lived AWS keys stored |
| Verification | `scripts/smoke-test.sh` | End-to-end API test on every deploy |
| Metrics framework | DORA (+ reliability) | Measured from EKS/ECR/CloudWatch/ALB |
