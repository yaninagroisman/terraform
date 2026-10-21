resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.14.1"

  values = [
    file("${path.module}/helm/aws-load-balancer-controller/values.yaml")
  ]

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = module.network.vpc_id
    },
    {
      name  = "backendSecurityGroup"
      value = aws_security_group.alb_backend.id
    },
    {
      # was a hardcoded ARN with the account ID in values.yaml
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.eks.alb_controller_role_arn
    }
  ]

  wait    = true
  timeout = 300

  depends_on = [
    module.eks
  ]
}
resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  namespace = "kube-system"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"

  wait    = true
  timeout = 300

  depends_on = [helm_release.aws_load_balancer_controller]
}