resource "helm_release" "weather_app" {
  name      = "weather-app"
  namespace = "weather"

  chart = "${path.module}/helm/weather-app"

  values = [
    file("${path.module}/helm/weather-app/values.yaml")
  ]

  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_namespace_v1.weather,
    helm_release.secret_store,
    helm_release.aws_load_balancer_controller,
    helm_release.metrics_server
  ]
}