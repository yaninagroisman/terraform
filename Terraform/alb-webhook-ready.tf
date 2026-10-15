resource "terraform_data" "alb_webhook_ready" {
  triggers_replace = [
    module.eks.cluster_endpoint
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      SECONDS=0
      set -euo pipefail

      aws eks update-kubeconfig \
        --region eu-north-1 \
        --name infinity-weather-eks

      echo "Waiting for ALB Controller Deployment..."

      until kubectl get deployment aws-load-balancer-controller \
        -n kube-system >/dev/null 2>&1; do
        if (( SECONDS >= 300 )); then
          echo "Timeout waiting for ALB webhook resources"
          exit 1
        fi
        sleep 5
      done

      kubectl rollout status \
        deployment/aws-load-balancer-controller \
        -n kube-system \
        --timeout=300s

      echo "Waiting for ALB webhook endpoints..."

      until kubectl get endpoints aws-load-balancer-webhook-service \
        -n kube-system \
        -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null \
        | grep -q .; do
        if (( SECONDS >= 300 )); then
          echo "Timeout waiting for ALB webhook resources"
          exit 1
        fi
        sleep 5
      done

      echo "ALB webhook is ready!"
    EOT
  }

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}