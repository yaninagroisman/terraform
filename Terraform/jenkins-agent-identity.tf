resource "kubernetes_service_account_v1" "jenkins_agent" {
  metadata {
    name      = "jenkins-agent"
    namespace = "jenkins"
  }
  depends_on = [
    kubernetes_namespace_v1.jenkins
  ]
}

data "aws_iam_policy_document" "jenkins_agent_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins_agent" {
  name               = "infinity-weather-jenkins-agent"
  assume_role_policy = data.aws_iam_policy_document.jenkins_agent_assume.json
}

resource "aws_iam_role_policy" "jenkins_agent" {
  name = "jenkins-agent-eks-access"
  role = aws_iam_role.jenkins_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "jenkins_agent" {
  cluster_name    = module.eks.cluster_name
  namespace       = "jenkins"
  service_account = kubernetes_service_account_v1.jenkins_agent.metadata[0].name
  role_arn        = aws_iam_role.jenkins_agent.arn
}

resource "aws_eks_access_entry" "jenkins_agent" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = aws_iam_role.jenkins_agent.arn
  type              = "STANDARD"
  kubernetes_groups = ["jenkins-deployers"]
}

resource "aws_eks_access_policy_association" "jenkins_agent_weather" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.jenkins_agent.arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["weather"]
  }

  depends_on = [aws_eks_access_entry.jenkins_agent]
}

data "aws_caller_identity" "current" {}

