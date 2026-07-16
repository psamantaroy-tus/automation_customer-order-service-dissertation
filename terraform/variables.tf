variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster name (mirrors the manual build)"
  type        = string
  default     = "dissertation-cluster"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "db_username" {
  description = "Master username for both RDS instances"
  type        = string
  default     = "admin"
}

variable "customer_db_password" {
  description = "Master password for customer-db (from GitHub secret CUSTOMER_DB_PASSWORD)"
  type        = string
  sensitive   = true
}

variable "order_db_password" {
  description = "Master password for order-db (from GitHub secret ORDER_DB_PASSWORD)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

locals {
  tags = {
    Project   = "customer-order-dissertation"
    ManagedBy = "terraform"
  }
}
