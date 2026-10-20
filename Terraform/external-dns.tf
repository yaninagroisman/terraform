resource "helm_release" "external_dns" {
  name             = "external-dns"
  namespace        = "external-dns"
  create_namespace = true

  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"

  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      extraArgs = ["--aws-zone-type=public"]
      sources = ["ingress"]

      domainFilters = [trimsuffix(var.domain_name, ".")]

      policy = "upsert-only"

      registry   = "txt"
      txtOwnerId = "infinity-weather-eks"

      serviceAccount = {
        create = true
        name   = "external-dns"

        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
        }
      }
      txtPrefix          = "external-dns-"
      logLevel           = "info"
      managedRecordTypes = ["A"]
    })
  ]

  wait    = true
  timeout = 300

  depends_on = [
    module.eks,
    aws_iam_role_policy.external_dns,
    helm_release.aws_load_balancer_controller,
  ]
}