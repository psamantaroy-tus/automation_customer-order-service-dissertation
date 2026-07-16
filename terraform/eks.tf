# EKS cluster + managed node group via the official community module.
# This replaces manual Stages 2, 6, 7 (IAM roles, cluster, node group) and
# Stage 9's access fix — `enable_cluster_creator_admin_permissions` grants
# kubectl admin to whoever runs terraform (the GitHub Actions role in CI).
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = 1
      max_size       = var.node_desired_size
      desired_size   = var.node_desired_size
      disk_size      = 20
    }
  }

  tags = local.tags
}
