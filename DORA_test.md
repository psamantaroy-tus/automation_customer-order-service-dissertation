Manual DORA Test Cases

Test ID: DORA-DF-01
Objective: Measure Deployment Frequency
AWS Console path: EKS > Clusters > dissertation-cluster > Workloads
Steps:

Open each workload rollout history for customer-service and order-service.

Count completed successful deployments in your reporting window.

Record date and time of each successful rollout.
Metric output:
Deployment Frequency = Number of successful deployments / time window
Pass condition:
You can produce a clear count and trend per day or per week.

Test ID: DORA-LT-01
Objective: Measure Lead Time for Changes
AWS Console path: ECR > Repositories and EKS > Workloads
Steps:

In ECR, find image push timestamp for a release image.

In EKS workload rollout, find timestamp when that image is running in pods.

Subtract push time from running time.
Metric output:
Lead Time = Deployment running time - image push time
Pass condition:
Lead time is measurable for each release and can be averaged.

Test ID: DORA-CFR-01
Objective: Measure Change Failure Rate
AWS Console path: EKS > Workloads, CloudWatch > Logs, CloudWatch > Alarms
Steps:

For each deployment in window, mark success or failure.

Mark as failure if rollback happened, pods entered CrashLoopBackOff, or post-deploy health failed.

Count failed deployments and total deployments.
Metric output:
Change Failure Rate = Failed deployments / Total deployments x 100
Pass condition:
Each deployment has a success or failure label with evidence.

Test ID: DORA-MTTR-01
Objective: Measure Mean Time to Restore
AWS Console path: CloudWatch > Alarms, CloudWatch > Logs, EKS > Workloads
Steps:

Identify an incident start time (alarm fired or health endpoint failure).

Identify restore time (pods healthy, endpoint healthy, alarm cleared).

Calculate restore duration for each incident.
Metric output:
MTTR = Sum of all restore durations / Number of incidents
Pass condition:
Incident and recovery timestamps are captured and reproducible.

Test ID: DORA-REL-01
Objective: Measure Reliability (DORA fifth metric)
AWS Console path: EC2 > Load Balancers > Monitoring and CloudWatch Metrics
Steps:

Track ALB 5XX errors, target response time, and healthy host count.

Record outage windows where healthy host count dropped or 5XX spiked.

Calculate availability in the reporting window.
Metric output:
Reliability view = Availability percentage + error rate trend
Pass condition:
You can show stable healthy targets and low error rates over time.

Test ID: DORA-VAL-01
Objective: Validate metric integrity
AWS Console path: EKS, ECR, CloudWatch
Steps:

Pick one release and cross-check timestamps across ECR push, EKS rollout, and CloudWatch logs.

Confirm all three sources tell a consistent timeline.
Pass condition:
No major timestamp mismatch; data is trustworthy for dissertation reporting.

Evidence to capture for dissertation

Screenshot of EKS rollout history with timestamps.
Screenshot of ECR image push history.
Screenshot of CloudWatch alarms and alarm history.
Screenshot of ALB metrics (5XX, healthy hosts, latency).
One filled metric sheet for at least 5 to 10 deployments.

## Rollout Execution Record: Order Service (ZAWS EKS)

Date: 2026-07-11  
Cluster: dissertation-cluster  
Namespace: default  
Service Endpoint: http://a80af352e7286468c960dffb7cb87bb5-1513205418.eu-west-1.elb.amazonaws.com

### 1) Old image tag and new image tag
- Old image tag: 664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service:latest
- New image tag: 664858858732.dkr.ecr.eu-west-1.amazonaws.com/order-service:latest
- Rollout type: deployment restart (same image tag, new pod revision)

### 2) Rollout start and end time
- Rollout start time: 2026-07-11T18:06:03.1523910+01:00
- Rollout end time: 2026-07-11T18:06:57.5903682+01:00
- Duration: 54.44 seconds

### 3) Number of pods replaced
- Pods before rollout: 1
- Pod before rollout: order-service-6b75b6f4c4-cqjhg
- Pods after rollout (stable): 1
- Pod after rollout: order-service-7475894c5d-f89j8
- Number of pods replaced: 1

### 4) Health check result before and after
- Health before rollout (time: 2026-07-11T18:05:31.4668642+01:00): {"groups":["liveness","readiness"],"status":"UP"}
- Health after rollout (time: 2026-07-11T18:07:02.1839111+01:00): {"groups":["liveness","readiness"],"status":"UP"}
- Result: No service degradation observed.

### 5) Any rollback performed and reason
- Rollback performed: No
- Reason: Not required, rollout completed successfully and post-rollout health was UP.

### Command trail used (evidence)
- kubectl rollout restart deployment/order-service
- kubectl rollout status deployment/order-service --timeout=300s
- kubectl get pods -l app=order-service -o wide
- Invoke-WebRequest http://a80af352e7286468c960dffb7cb87bb5-1513205418.eu-west-1.elb.amazonaws.com/actuator/health