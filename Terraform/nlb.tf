module "git_nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.1"

  name               = "${var.project_name}-git-nlb"
  load_balancer_type = "network"

  vpc_id  = module.network.vpc_id
  subnets = module.network.public_subnet_ids

  internal = false

  security_groups = [aws_security_group.git_nlb.id]

  listeners = {
    ssh = {
      port     = 22
      protocol = "TCP"

      forward = {
        target_group_key = "gitlab"
      }
    }
  }
  target_groups = {
    gitlab = {
      name        = "${var.project_name}-git-ssh-2222"
      protocol    = "TCP"
      port        = 2222
      target_type = "instance"

      target_id = module.ec2.instance_ids["gitlab"]

      health_check = {
        protocol = "TCP"
        port     = "2222"
      }
    }
  }
  enable_deletion_protection = false
}