resource "aws_acm_certificate" "developer" {
  domain_name = "git.${var.domain_name}"

  subject_alternative_names = [
    "jenkins.${var.domain_name}"
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-developer-cert"
  }
}
resource "aws_route53_record" "developer_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.developer.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]

  ttl = 60
}
resource "aws_acm_certificate_validation" "developer" {
  certificate_arn = aws_acm_certificate.developer.arn

  validation_record_fqdns = [
    for record in aws_route53_record.developer_cert_validation :
    record.fqdn
  ]
}
# Weather App SSL Certificate
resource "aws_acm_certificate" "weather" {
  domain_name       = "weather.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-weather-cert"
  }
}

# DNS validation record
resource "aws_route53_record" "weather_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.weather.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]

  ttl = 60
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "weather" {
  certificate_arn = aws_acm_certificate.weather.arn

  validation_record_fqdns = [
    for record in aws_route53_record.weather_cert_validation :
    record.fqdn
  ]
}
