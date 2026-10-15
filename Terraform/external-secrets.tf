resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"

  wait    = true
  timeout = 300

  depends_on = [
    module.eks,
    aws_iam_role_policy.external_secrets,
    helm_release.aws_load_balancer_controller
  ]
  set = [
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.external_secrets.arn
    }
  ]
}