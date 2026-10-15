resource "kubernetes_service_account_v1" "jenkins_agents" {
  metadata {
    name      = "jenkins-controller"
    namespace = "jenkins"
  }
}

resource "kubernetes_role_v1" "jenkins_agents" {
  metadata {
    name      = "jenkins-agent-manager"
    namespace = "jenkins"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
}

resource "kubernetes_role_binding_v1" "jenkins_agents" {
  metadata {
    name      = "jenkins-agent-manager"
    namespace = "jenkins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_agents.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.jenkins_agents.metadata[0].name
    namespace = "jenkins"
  }
}
resource "kubernetes_secret_v1" "jenkins_controller_token" {
  metadata {
    name      = "jenkins-controller-token"
    namespace = "jenkins"

    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.jenkins_agents.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}