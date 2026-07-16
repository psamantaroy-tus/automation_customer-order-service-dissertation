# Kubernetes Secrets holding the DB credentials, created by Terraform instead
# of the manual `kubectl create secret` step (manual Stage 10). The deployment
# manifests reference these by name (customer-db-secret / order-db-secret).
resource "kubernetes_secret" "customer_db" {
  metadata {
    name = "customer-db-secret"
  }
  data = {
    username = var.db_username
    password = var.customer_db_password
  }
  type = "Opaque"
}

resource "kubernetes_secret" "order_db" {
  metadata {
    name = "order-db-secret"
  }
  data = {
    username = var.db_username
    password = var.order_db_password
  }
  type = "Opaque"
}
