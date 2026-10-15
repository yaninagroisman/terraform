module "eks" {
  source = "terraform-aws-modules/eks/aws"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  addons = {
    vpc-cni = {
      before_compute = true
    }

    kube-proxy = {
      before_compute = true
      addon_version  = "v1.36.0-eksbuild.25"
    }
    eks-pod-identity-agent = {}
    coredns                = {}
  }

  eks_managed_node_groups = {
    workers = {
      name            = "workers"
      use_name_prefix = false

      subnet_ids = var.private_subnet_ids

      instance_types = ["t3.medium"]

      min_size     = 2
      max_size     = 4
      desired_size = 2
    }
  }
  endpoint_private_access = true
  endpoint_public_access  = true

  endpoint_public_access_cidrs             = var.cluster_endpoint_public_access_cidrs
  enable_cluster_creator_admin_permissions = true
  access_entries = {
    jenkins = {
      principal_arn     = var.jenkins_role_arn
      kubernetes_groups = ["jenkins-deployers"]


      policy_associations = {
        jenkins_access = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

          access_scope = {
            type       = "namespace"
            namespaces = ["jenkins"]
          }
        }
      }
    }
  }
}

