locals {
  # Argo CD reads the GitOps repository directly from GitLab inside the VPC
  gitops_repo_url = coalesce(
    var.gitops_repo_url,
    "ssh://git@gitlab.internal.${var.domain_name}:2222/${var.gitlab_group}/weather-gitops.git"
  )

  # Local Argo CD accounts are declarative, so a rebuilt cluster needs no manual steps.
  # User names are not secret, only the password hashes are.
  argocd_readonly_user_names = nonsensitive(keys(var.argocd_readonly_users))

  argocd_cm = { for user in local.argocd_readonly_user_names : "accounts.${user}" => "login" }

  argocd_rbac = {
    "policy.default" = ""
    "policy.csv" = join("\n", concat(
      [for user in local.argocd_readonly_user_names : "g, ${user}, role:readonly"],
      ["p, role:readonly, logs, get, */*, allow"]
    ))
  }

  argocd_secret = merge(
    {
      # tfvars hash if set, otherwise the generated password (terraform output -raw argocd_admin_password)
      argocdServerAdminPassword = coalesce(
        var.argocd_admin_password_bcrypt,
        random_password.argocd_admin.bcrypt_hash
      )
      argocdServerAdminPasswordMtime = "2026-01-01T00:00:00Z"
    },
    {
      extra = merge({}, [
        for user in local.argocd_readonly_user_names : {
          "accounts.${user}.password"      = var.argocd_readonly_users[user]
          "accounts.${user}.passwordMtime" = "2026-01-01T00:00:00Z"
        }
      ]...)
    }
  )
}

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
    configs = merge(
      {
        params = { "server.insecure" = true }
        cm     = local.argocd_cm
        rbac   = local.argocd_rbac
        secret = local.argocd_secret
      },
      var.gitlab_ssh_known_hosts == "" ? {} : {
        ssh = { extraHosts = var.gitlab_ssh_known_hosts }
      }
    )
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

# Repository credentials, AppProject and Application. Before this existed they were
# created by hand in the Argo CD UI, so a fresh `terraform apply` deployed no application.
resource "helm_release" "argocd_config" {
  name      = "argocd-config"
  namespace = "argocd"
  chart     = "${path.module}/helm/argocd-config"
  wait      = true
  timeout   = 300

  values = [yamlencode({
    repoURL            = local.gitops_repo_url
    repoKeySecret      = "infinity-weather/argocd-repo-key"
    clusterSecretStore = "aws-secrets-manager"
    insecure           = var.gitlab_ssh_known_hosts == ""
    project            = "weather"
    app = {
      name           = var.argocd_app_name
      path           = "apps/weather"
      targetRevision = "main"
      namespace      = kubernetes_namespace_v1.weather.metadata[0].name
      releaseName    = "weather-app"
      helmParameters = [
        {
          name  = "ingress.certificateArn"
          value = aws_acm_certificate_validation.weather.certificate_arn
        }
      ]
    }
  })]

  depends_on = [
    helm_release.argocd,                  # Application / AppProject CRDs
    helm_release.secret_store,            # ClusterSecretStore for the repository key
    helm_release.external_dns,            # DNS record for weather.<domain>
    aws_iam_role_policy.external_dns,
    aws_iam_role_policy.external_secrets, # ESO may read the repository key and the API key
  ]
}
