
 Ref ARCHITECTURE / RESEARCH METHODOLOGY 
 
1. ARCHITECTURE / SYSTEM DESIGN
Two microservices: customer-service and order-service. Each service has its own MySQL database.
•	Two services:
Customer Service and Order Service are two separate small applications (microservices).
•	Own databases:
Each service has its own MySQL database (customer_db and order_db). They do not share a database.
•	Communication:
Order Service talks to Customer Service using HTTP calls (via RestTemplate).
•	Containers:
Both services are packaged into Docker containers using multi-stage Docker files.
•	Orchestration:
Kubernetes is used to run and manage these containers.
•	Target cloud:
Final deployment target is AWS EKS (managed Kubernetes on AWS).
2. DEVELOPMENT TOOL AND TECH STACK
The project uses with Spring Boot. Maven handles the build process, while Docker and Docker Compose manage containerization and Kubernetes mange the orchestrations.
•	Framework:
Spring Boot is used to quickly build REST APIs and handle configuration.
•	Build tool:
Maven compiles the code, runs tests, and creates JAR files.
•	Containers:
Docker builds images; Docker Compose runs multiple containers locally (services + databases).
•	Kubernetes manifests:
YAML files describe how the services run in Kubernetes (replicas, resources, env vars, etc.).
•	CI/CD:
GitHub Actions runs the pipeline automatically on each push.
•	Image registry & cloud:
Images are pushed to Docker Hub or AWS ECR, then deployed to AWS EKS.

CI/CD stages (simple view):
1.	Build & Test: Maven builds and tests
2.	Docker Build & Push: Docker image is built and pushed to a registry.
3.	Deploy: Kubernetes deploys the image to AWS EKS.

3. MICROSERVICES
The proposed system is designed as a microservices architecture comprising two independently deployable services.
•	Microservices:
Two independent services: Customer Service and Order Service.
•	Customer Service:
Manages customer data (name, email, creation date) in customer_db.
Endpoints: create, get by id, get all, delete.
•	Order Service:
Manages orders (date, amount, customerId) in order_db.
•	No shared DB:
Each service has its own database.
•	Customer validation:
Order Service stores only customer ID and checks the customer via HTTP call to Customer Service.
•	Loose coupling:
Each service can be built, tested, and deployed separately.
•	Communication style:
Synchronous HTTP (simple and easy for a prototype).

4. DEVELOPMENT 
For containerisation, each service uses a multi-stage Dockerfil. Docker Compose is used for local development.
•	 Dockerfiles:
Build JAR with Maven and dockized each services

•	Docker Compose (local):
Runs both services and both MySQL databases on one network with health checks.
•	Kubernetes manifests:
o	deployment.yaml: replicas, CPU/memory limits.
o	service.yaml: exposes each service inside the cluster.
•	Health checks:
Kubernetes actuator/health to see if the app is alive and ready and the pods are healthy.
•	Secrets:
DB credentials are stored in Kubernetes Secrets, not hardcoded.

5. SUMMERY
This chapter described the methodology used to design, develop, and evaluate the proposed system.
•	Architecture:
Two Spring Boot microservices (Customer and Order), each with its own MySQL DB and REST API.
•	Deployment:
Containerised with Docker, orchestrated by Kubernetes, targeting AWS EKS.
•	Tooling:
Spring Boot 4.0.2, Maven, Docker, Kubernetes, GitHub Actions.
•	Automation:
All stages and checks run inside the CI/CD pipeline before deployment and will 

6. COMPAIRE, LATENCY CHECK AND EVALUATION
The following chapter will show actual results: pipeline runs, and how they relate to the research goals – It will compare manual aws infra set up VS automated config through terraform and evaluate deployment time taken and rate of error. To evaluate speed and latency, record the total time taken for each deployment cycle. By measuring how long every rebuild and redeploy process takes, you can directly compare deployment performance across runs.

7. ARCHITECTURAL DIAGRAM DESIGN: 

1.	Developer push → GitHub (main branch)

↓
2.	Trigger GitHub Actions Pipeline

↓

3.	Job 1: Build 

↓

4.	Job 2: Docker Build & Push (Docker Hub / AWS ECR)

↓

5.	Job 3: Deploy to Target Environment (Kubernetes on AWS EKS)

↓

6.	Run services on Kubernetes Cluster (AWS EKS & PODs)
customer-service Pod  ←→  mysql-customer Pod
order-service Pod     ←→  mysql-order Pod

↓

7.	Measure → Latency time output to verify  time in order to measure deployment and rebuild time for each pipeline run.

