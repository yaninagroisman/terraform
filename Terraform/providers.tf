terraform {
  required_version = ">= 1.10.0" # use_lockfile требует 1.10+

  backend "s3" {
    bucket       = "yanina-terraform-test"
    key          = "infinity-weather/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
provider "kubernetes" {
  host = module.eks.cluster_endpoint

  cluster_ca_certificate = base64decode(
    module.eks.cluster_certificate_authority_data
  )

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", "eu-north-1"
    ]
  }
}

provider "helm" {
  kubernetes = {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority_data
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", "eu-north-1"
      ]
    }
  }
}