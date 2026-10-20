output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}
output "argocd_certificate_arn" { value = aws_acm_certificate_validation.argocd.certificate_arn }