resource "aws_security_group" "alb_backend" {
  name_prefix = "eks-alb-backend-"
  description = "Shared backend security group for AWS Load Balancer Controller"

  vpc_id = module.network.vpc_id

  tags = {
    Name = "eks-alb-backend"
  }
}