# EKS cluster + managed node group via the official community module.
# This replaces manual Stages 2, 6, 7 (IAM roles, cluster, node group) and
# Stage 9's access fix. enable_cluster_creator_admin_permissions grants kubectl
# admin to whoever runs terraform (the GitHub Actions role in CI); the
# access_entries block additionally grants your local IAM user admin so kubectl
# works from your laptop after every rebuild.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # Grant your local IAM user cluster-admin so kubectl works from your laptop
  # on every rebuild (no manual access-entry step needed).
  access_entries = {
    local_admin = {
      principal_arn = var.admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

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
