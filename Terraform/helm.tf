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
      name  = "vpcId"
      value = module.network.vpc_id
    },
    {
      name  = "backendSecurityGroup"
      value = aws_security_group.alb_backend.id
    }
  ]

  wait    = true
  timeout = 300

  depends_on = [
    module.eks,
    module.network,
    helm_release.metrics_server
  ]
}
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"

  wait    = true
  timeout = 300

  depends_on = [
    module.eks
  ]
}