module "developer_alb" {
  source = "terraform-aws-modules/alb/aws"

  name               = "${var.project_name}-developer-alb"
  load_balancer_type = "application"

  vpc_id  = module.network.vpc_id
  subnets = module.network.public_subnet_ids

  internal = false

  security_groups = [aws_security_group.developer_alb.id]

  target_groups = {
    gitlab = {
      name        = "${var.project_name}-gitlab"
      protocol    = "HTTPS"
      port        = 443
      target_type = "instance"

      target_id = module.ec2.instance_ids["gitlab"]
    }

    jenkins = {
      name        = "${var.project_name}-jenkins-8081"
      protocol    = "HTTP"
      port        = 8081
      target_type = "instance"

      target_id = module.ec2.instance_ids["jenkins"]

      health_check = {
        enabled             = true
        path                = "/login"
        protocol            = "HTTP"
        matcher             = "200"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 30
        timeout             = 5
      }
    }
  }
  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate_validation.developer.certificate_arn

      forward = {
        target_group_key = "gitlab"
      }
      rules = {
        gitlab = {
          priority = 10

          actions = [{
            forward = {
              target_group_key = "gitlab"
            }
          }]

          conditions = [{
            host_header = {
              values = ["git.${var.domain_name}"]
            }
          }]
        }

        jenkins = {
          priority = 20

          actions = [{
            forward = {
              target_group_key = "jenkins"
            }
          }]

          conditions = [{
            host_header = {
              values = ["jenkins.${var.domain_name}"]
            }
          }]
        }
      }
    }
  }
  enable_deletion_protection = false
}