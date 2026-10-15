output "instance_ids" {
  value = {
    for name, instance in module.instances :
    name => instance.id
  }
}
output "iam_role_arns" {
  description = "IAM Role ARNs for EC2 instances"

  value = {
    for name, instance in module.instances :
    name => instance.iam_role_arn
  }
}
output "iam_role_names" {
  description = "IAM Role names for EC2 instances"

  value = {
    for name, instance in module.instances :
    name => instance.iam_role_name
  }
}
output "security_group_ids" {
  description = "Security Group IDs for EC2 instances"
  value       = var.security_group_ids
}