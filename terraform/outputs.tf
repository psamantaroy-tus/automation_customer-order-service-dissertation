# Consumed by the GitHub Actions deploy job to render the k8s manifests.

output "cluster_name" {
  description = "EKS cluster name (for aws eks update-kubeconfig)"
  value       = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "customer_service_ecr_url" {
  description = "ECR repo URL for customer-service"
  value       = aws_ecr_repository.customer_service.repository_url
}

output "order_service_ecr_url" {
  description = "ECR repo URL for order-service"
  value       = aws_ecr_repository.order_service.repository_url
}

output "customer_db_endpoint" {
  description = "customer-db host:port"
  value       = aws_db_instance.customer.endpoint
}

output "order_db_endpoint" {
  description = "order-db host:port"
  value       = aws_db_instance.order.endpoint
}

# Just the hostname (no :port) for building JDBC URLs in the manifests.
output "customer_db_host" {
  value = aws_db_instance.customer.address
}

output "order_db_host" {
  value = aws_db_instance.order.address
}
