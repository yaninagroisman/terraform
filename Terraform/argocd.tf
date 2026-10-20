resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.5"
  wait             = true
  timeout          = 600

  values = [yamlencode({
    global = { domain = "argocd.${var.domain_name}" }
    configs = {
      params = { "server.insecure" = true }
    }
    dex            = { enabled = false }
    notifications  = { enabled = false }
    applicationSet = { enabled = false }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = "alb"
        hostname         = "argocd.${var.domain_name}"
        annotations = {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/certificate-arn"  = aws_acm_certificate_validation.argocd.certificate_arn
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
          "alb.ingress.kubernetes.io/inbound-cidrs"    = join(",", var.admin_cidrs)
          "external-dns.alpha.kubernetes.io/hostname"  = "argocd.${var.domain_name}"
        }
      }
    }
  })]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.argocd,
  ]
}