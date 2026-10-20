resource "aws_route53_zone" "internal" {
  name = "internal.${var.domain_name}"
  vpc {
    vpc_id = module.network.vpc_id
  }
}

resource "aws_route53_record" "internal" {
  for_each = module.ec2.private_ips
  zone_id  = aws_route53_zone.internal.zone_id
  name     = "${each.key}.internal.${var.domain_name}"
  type     = "A"
  ttl      = 60
  records  = [each.value]
}