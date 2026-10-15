resource "aws_vpc_security_group_ingress_rule" "jenkins_to_eks_api" {
  security_group_id = module.eks.cluster_security_group_id

  referenced_security_group_id = module.ec2.security_group_ids["jenkins"][0]

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  description = "Allow Jenkins EC2 to access EKS private API"
}
resource "aws_vpc_security_group_ingress_rule" "eks_agents_to_jenkins" {
  security_group_id = module.ec2.security_group_ids["jenkins"][0]

  referenced_security_group_id = module.eks.node_security_group_id

  ip_protocol = "tcp"
  from_port   = 8081
  to_port     = 8081

  description = "Allow EKS agents to connect to Jenkins HTTPS"
}
