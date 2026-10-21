# Grafana (exercise 3): runs in the monitoring docker compose on the monitoring host (:3000),
# published at https://grafana.<domain> through the Developer ALB, so only admin_cidrs can reach it.
# Datasource and dashboards are files in ./monitoring/grafana and arrive through the same S3 sync.

# ---------- Admin password ----------

resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

# Delivered to the host with the rest of the config (private bucket, read by the instance role only).
# Grafana reads it via GF_SECURITY_ADMIN_PASSWORD__FILE on its first start.
resource "aws_s3_object" "grafana_admin_password" {
  bucket       = aws_s3_bucket.monitoring.id
  key          = "secrets/grafana-admin-password"
  content      = random_password.grafana_admin.result
  content_type = "text/plain"
}

# ---------- Network: Developer ALB -> Grafana ----------

resource "aws_vpc_security_group_ingress_rule" "monitoring_grafana_from_alb" {
  security_group_id            = aws_security_group.monitoring.id
  referenced_security_group_id = aws_security_group.developer_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  description                  = "Grafana from the Developer ALB"
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.project_name}-grafana"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.network.vpc_id

  health_check {
    path                = "/api/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_target_group_attachment" "grafana" {
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = aws_instance.monitoring.id
  port             = 3000
}

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = module.developer_alb.listeners["https"].arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    host_header {
      values = ["grafana.${var.domain_name}"]
    }
  }
}

# ---------- Certificate and DNS ----------
# Own certificate, added to the existing HTTPS listener (SNI): the git/jenkins certificate is not touched.

resource "aws_acm_certificate" "grafana" {
  domain_name       = "grafana.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-grafana-cert"
  }
}

resource "aws_route53_record" "grafana_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.grafana.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "grafana" {
  certificate_arn         = aws_acm_certificate.grafana.arn
  validation_record_fqdns = [for r in aws_route53_record.grafana_cert_validation : r.fqdn]
}

resource "aws_lb_listener_certificate" "grafana" {
  listener_arn    = module.developer_alb.listeners["https"].arn
  certificate_arn = aws_acm_certificate_validation.grafana.certificate_arn
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.developer_alb.dns_name
    zone_id                = module.developer_alb.zone_id
    evaluate_target_health = true
  }
}

# ---------- Outputs ----------

output "grafana_url" {
  value = "https://grafana.${var.domain_name}"
}

output "grafana_admin_password" {
  description = "Grafana admin password: terraform output -raw grafana_admin_password"
  value       = random_password.grafana_admin.result
  sensitive   = true
}
