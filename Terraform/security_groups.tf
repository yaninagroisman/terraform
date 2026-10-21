resource "aws_security_group" "developer_alb" {
  name        = "${var.project_name}-developer-alb-sg"
  description = "Security group for Developer ALB"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.project_name}-developer-alb-sg"
  }
}

resource "aws_security_group" "gitlab" {
  name        = "${var.project_name}-gitlab-sg"
  description = "Security group for GitLab"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.project_name}-gitlab-sg"
  }
}

resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Security group for Jenkins Controller"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

# Keyed by position in admin_cidrs: changing an address updates the rule in place
# (keying by CIDR would delete + create, and AWS rejects a duplicate rule created in parallel).
locals {
  admin_cidrs_by_index = { for i, cidr in var.admin_cidrs : tostring(i) => cidr }
}

# Former single rules (office = admin_cidrs[0], home = admin_cidrs[1]) are moved, not recreated
moved {
  from = aws_vpc_security_group_ingress_rule.developer_alb_https
  to   = aws_vpc_security_group_ingress_rule.developer_alb_https["0"]
}
moved {
  from = aws_vpc_security_group_ingress_rule.developer_alb_https_home
  to   = aws_vpc_security_group_ingress_rule.developer_alb_https["1"]
}
moved {
  from = aws_vpc_security_group_ingress_rule.git_nlb_ssh_from_office
  to   = aws_vpc_security_group_ingress_rule.git_nlb_ssh["0"]
}
moved {
  from = aws_vpc_security_group_ingress_rule.git_nlb_ssh_from_home
  to   = aws_vpc_security_group_ingress_rule.git_nlb_ssh["1"]
}

resource "aws_vpc_security_group_ingress_rule" "developer_alb_https" {
  for_each          = local.admin_cidrs_by_index
  security_group_id = aws_security_group.developer_alb.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  cidr_ipv4   = each.value
  description = "HTTPS to GitLab and Jenkins from an admin network"
}
resource "aws_vpc_security_group_egress_rule" "developer_alb_out" {
  security_group_id = aws_security_group.developer_alb.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}


resource "aws_vpc_security_group_ingress_rule" "gitlab_from_alb" {
  security_group_id = aws_security_group.gitlab.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  referenced_security_group_id = aws_security_group.developer_alb.id
}
resource "aws_vpc_security_group_egress_rule" "gitlab_out" {
  security_group_id = aws_security_group.gitlab.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}



resource "aws_vpc_security_group_ingress_rule" "jenkins_from_alb" {
  security_group_id = aws_security_group.jenkins.id

  from_port   = 8081
  to_port     = 8081
  ip_protocol = "tcp"

  referenced_security_group_id = aws_security_group.developer_alb.id
}
resource "aws_vpc_security_group_egress_rule" "jenkins_out" {
  security_group_id = aws_security_group.jenkins.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "gitlab_ssh_from_nlb" {
  security_group_id = aws_security_group.gitlab.id

  from_port   = 2222
  to_port     = 2222
  ip_protocol = "tcp"

  referenced_security_group_id = aws_security_group.git_nlb.id
}
resource "aws_security_group" "git_nlb" {
  name        = "${var.project_name}-git-nlb-sg"
  description = "Security group for Git SSH NLB"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.project_name}-git-nlb-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "git_nlb_ssh" {
  for_each          = local.admin_cidrs_by_index
  security_group_id = aws_security_group.git_nlb.id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  cidr_ipv4   = each.value
  description = "Git over SSH from an admin network"
}
resource "aws_vpc_security_group_egress_rule" "git_nlb_to_gitlab" {
  security_group_id = aws_security_group.git_nlb.id

  from_port   = 2222
  to_port     = 2222
  ip_protocol = "tcp"

  referenced_security_group_id = aws_security_group.gitlab.id
}
resource "aws_vpc_security_group_ingress_rule" "gitlab_ssh_from_jenkins" {
  security_group_id = aws_security_group.gitlab.id

  from_port   = 2222
  to_port     = 2222
  ip_protocol = "tcp"

  referenced_security_group_id = aws_security_group.jenkins.id
}
resource "aws_vpc_security_group_ingress_rule" "gitlab_ssh_from_eks" {
  security_group_id            = aws_security_group.gitlab.id
  referenced_security_group_id = module.eks.node_security_group_id

  ip_protocol = "tcp"
  from_port   = 2222
  to_port     = 2222

  description = "Allow EKS Jenkins agents to access GitLab SSH"
}
resource "aws_vpc_security_group_ingress_rule" "jenkins_from_gitlab" {
  security_group_id            = aws_security_group.jenkins.id
  referenced_security_group_id = aws_security_group.gitlab.id
  ip_protocol                  = "tcp"
  from_port                    = 8081
  to_port                      = 8081
  description                  = "GitLab webhooks to Jenkins"
}