# Argo CD admin password, generated once and kept in the Terraform state.
# terraform destroy removes it, the next apply generates a new one.
resource "random_password" "argocd_admin" {
  length  = 24
  special = false # letters and digits: no quoting problems in a shell
}

output "argocd_admin_password" {
  description = "Argo CD admin password: terraform output -raw argocd_admin_password"
  value       = random_password.argocd_admin.result
  sensitive   = true
}
