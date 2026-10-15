resource "aws_iam_policy" "jenkins_secrets" {
  name        = "${var.project_name}-jenkins-secrets"
  description = "Allow Jenkins to read its admin password"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:eu-north-1:060941289583:secret:infinity-weather/jenkins-admin-password-hdi9MZ"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_secrets" {
  role       = module.ec2.iam_role_names["jenkins"]
  policy_arn = aws_iam_policy.jenkins_secrets.arn
}
