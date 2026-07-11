# CI_CD_Automation_CustomerOrder_microservice
Automate and Deploy the dockerized microservices using Github action 


```
push / pull_request to main
           ↓
     Build & Test
           ↓
  SonarCloud Analysis
           ↓
  Docker Build & Push
           ↓
   Deploy to Server
```

Each job depends on the previous using `needs:`, so the pipeline **stops immediately** if any stage fails.

---

## Required GitHub Secrets

| Secret Name       | Description                              |
|-------------------|------------------------------------------|
| `SONAR_TOKEN`     | SonarCloud authentication token         |
| `SONAR_ORG`       | SonarCloud organization key             |
| `DOCKER_USERNAME` | Docker Hub username                     |
| `DOCKER_PASSWORD` | Docker Hub password or access token     |
| `SERVER_HOST`     | IP or hostname of the remote server     |
| `SERVER_USER`     | SSH username on the remote server       |
| `SERVER_SSH_KEY`  | Private SSH key for server access       |

---

## Notes
- `GITHUB_TOKEN` is automatically provided by GitHub Actions — no manual setup needed.
- The `sonar.qualitygate.wait=true` flag ensures the pipeline fails if code quality standards are not met.
- Using `|| true` in the deploy script allows the pipeline to continue even if no existing container is running.

## Run the Project (Branch: Dissertation)

- cd CI_CD_Automation_CustomerOrder_microservice
 - docker-compose up --build

## Test APIs
- GET http://localhost:8081/customer/customers
- GET http://localhost:8082/order/allpaginatedorders


### Docker Image Repository

https://eu-west-1.console.aws.amazon.com/ecr/repositories/private/729854242652/customer-service/_/details?region=eu-west-1

729854242652.dkr.ecr.eu-west-1.amazonaws.com/customer-service
729854242652.dkr.ecr.eu-west-1.amazonaws.com/order-service