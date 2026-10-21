output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Command that configures kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "instance_ids" {
  description = "EC2 instance IDs (aws ssm start-session --target <id>)"
  value       = module.ec2.instance_ids
}

output "argocd_url" {
  description = "Argo CD web UI"
  value       = "https://argocd.${var.domain_name}"
}

output "weather_url" {
  description = "Public application URL"
  value       = "https://weather.${var.domain_name}"
}

output "argocd_certificate_arn" {
  value = aws_acm_certificate_validation.argocd.certificate_arn
}

output "weather_certificate_arn" {
  value = aws_acm_certificate_validation.weather.certificate_arn
}
