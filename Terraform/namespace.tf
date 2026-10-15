resource "kubernetes_namespace_v1" "weather" {
  metadata {
    name = "weather"

    labels = {
      "app.kubernetes.io/part-of" = "infinity-weather"
    }
  }

  depends_on = [module.eks]
}