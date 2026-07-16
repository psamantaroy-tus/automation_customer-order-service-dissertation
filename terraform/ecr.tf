# Two ECR repositories, one per service (mirrors the manual build).
# force_delete lets `terraform destroy` remove them even when images exist,
# so the test cycle can be repeated cleanly.
resource "aws_ecr_repository" "customer_service" {
  name                 = "customer-service"
  force_delete         = true
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags
}

resource "aws_ecr_repository" "order_service" {
  name                 = "order-service"
  force_delete         = true
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags
}
