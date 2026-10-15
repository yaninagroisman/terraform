variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_endpoint_public_access_cidrs" {
  type = list(string)
}

variable "kubernetes_version" {
  type = string
}
variable "jenkins_role_arn" {
  description = "IAM Role ARN of Jenkins EC2 instance"
  type        = string
}