variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "infinity-weather"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Existing Route53 domain name"
  type        = string
}
variable "office_cidr" {
  description = "Public CIDR of the office network"
  type        = string
}
variable "jenkins_private_ip" {
  description = "Private IP of Jenkins Controller"
  type        = string
  default     = "10.0.12.124"
}
variable "admin_cidrs" {
  description = "Public CIDRs allowed to reach Argo CD UI (and later ALB/NLB/EKS API)"
  type        = list(string)
}
variable "gitlab_ebs_volume_id" {
  description = "Persistent EBS volume for GitLab"
  type        = string
}
variable "jenkins_ebs_volume_id" {
  description = "Persistent EBS volume for Jenkins"
  type        = string
  default     = "vol-0b409a613ee21b6e0"
}