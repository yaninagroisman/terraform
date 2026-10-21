# Cleanup hook for `terraform destroy`.
#
# The ALBs (and their security groups) for weather.<domain> and argocd.<domain> are created by the
# AWS Load Balancer Controller from Ingress objects, not by Terraform. They must be deleted while
# Argo CD and the controller are still running, otherwise the VPC, the subnets, the ACM
# certificates and the backend security group cannot be deleted (DependencyViolation /
# ResourceInUse), and the Argo CD Application stays stuck on its finalizer.
#
# Terraform destroys resources in reverse dependency order. Because this resource depends on
# Argo CD, the controller, ExternalDNS and the weather namespace, it is destroyed FIRST, while all
# of them are still alive. On create it does nothing.
#
# Requirements on the machine that runs destroy: aws CLI and kubectl, network access to the EKS API.
resource "terraform_data" "k8s_teardown" {
  input = {
    region   = var.aws_region
    cluster  = module.eks.cluster_name
    app_name = var.argocd_app_name
    script   = "${path.module}/scripts/k8s-teardown.sh"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = "bash '${self.input.script}'"
    environment = {
      REGION   = self.input.region
      CLUSTER  = self.input.cluster
      APP_NAME = self.input.app_name
    }
  }

  depends_on = [
    helm_release.argocd_config,
    helm_release.argocd,
    helm_release.aws_load_balancer_controller,
    helm_release.external_dns,
    kubernetes_namespace_v1.weather,
    # The controller deletes ALBs through the AWS API, reached via the NAT Gateways.
    # Without this, destroy removes NAT in parallel and the controller loses AWS access.
    module.network,
  ]
}
