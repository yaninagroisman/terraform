resource "aws_iam_policy" "jenkins_secrets" {
  name        = "${var.project_name}-jenkins-secrets"
  description = "Jenkins: read its admin password, describe the EKS cluster for its kubeconfig"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:infinity-weather/jenkins-admin-password-*"
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_secrets" {
  role       = module.ec2.iam_role_names["jenkins"]
  policy_arn = aws_iam_policy.jenkins_secrets.arn
}