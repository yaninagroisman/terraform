module "network" {
  source = "./modules/network"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr

  azs = [
    "eu-north-1a",
    "eu-north-1b"
  ]

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}

module "ec2" {
  source = "./modules/ec2"

  project_name       = var.project_name
  private_subnet_ids = module.network.private_subnet_ids

  security_group_ids = {
    gitlab  = [aws_security_group.gitlab.id]
    jenkins = [aws_security_group.jenkins.id]
  }

  instances = {
    gitlab = {
      ami           = "ami-0fe40a89e47747999"
      instance_type = "t3.large"
      subnet_index  = 0
      private_ip    = "10.0.11.67"
      user_data     = templatefile("${path.module}/gitlab-user-data.sh.tftpl", {})
    }

    jenkins = {
      ami           = "ami-0ce661e27efc9b836"
      instance_type = "t3.medium"
      subnet_index  = 1
      private_ip    = "10.0.12.124"
      user_data = templatefile("${path.module}/jenkins-user-data.sh.tftpl", {
        jenkins_volume_id        = var.jenkins_ebs_volume_id
        jenkins_volume_id_nodash = replace(var.jenkins_ebs_volume_id, "-", "")
      })
    }
  }
}
module "eks" {
  source = "./modules/eks"

  cluster_name = "${var.project_name}-eks"

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  kubernetes_version = "1.36"
  jenkins_role_arn   = module.ec2.iam_role_arns["jenkins"]

  cluster_endpoint_public_access_cidrs = [
    var.office_cidr,
    "46.210.40.120/32"
  ]
}
resource "kubernetes_namespace_v1" "jenkins" {
  metadata {
    name = "jenkins"
  }

  depends_on = [module.eks]
}