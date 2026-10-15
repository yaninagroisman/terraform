resource "kubernetes_role_v1" "jenkins_external_secrets" {
  metadata {
    name      = "jenkins-external-secrets"
    namespace = "weather"
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["externalsecrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  depends_on = [
    kubernetes_namespace_v1.weather
  ]
}

resource "kubernetes_role_binding_v1" "jenkins_external_secrets" {
  metadata {
    name      = "jenkins-external-secrets"
    namespace = "weather"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_external_secrets.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "jenkins-deployers"
    api_group = "rbac.authorization.k8s.io"
  }
}
