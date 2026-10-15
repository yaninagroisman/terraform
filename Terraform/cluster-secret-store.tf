/*resource "kubernetes_manifest" "aws_secrets_manager_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ClusterSecretStore"

    metadata = {
      name = "aws-secrets-manager"
    }

    spec = {
    }
  }

  depends_on = [
    helm_release.external_secrets
  ]
}*/
resource "helm_release" "secret_store" {
  name      = "secret-store"
  namespace = "external-secrets"

  chart = "${path.module}/helm/secret-store"

  wait    = true
  timeout = 300

  depends_on = [
    helm_release.external_secrets
  ]
}
