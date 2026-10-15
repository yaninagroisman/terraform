data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}
resource "aws_route53_record" "git_ssh" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "ssh.git.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.git_nlb.dns_name
    zone_id                = module.git_nlb.zone_id
    evaluate_target_health = true
  }
}
resource "aws_route53_record" "gitlab" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "git.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.developer_alb.dns_name
    zone_id                = module.developer_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "jenkins.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.developer_alb.dns_name
    zone_id                = module.developer_alb.zone_id
    evaluate_target_health = true
  }
}