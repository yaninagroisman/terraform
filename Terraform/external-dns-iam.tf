data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "infinity-weather-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
}

resource "aws_iam_role_policy" "external_dns" {
  name = "manage-weather-dns"
  role = aws_iam_role.external_dns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = data.aws_route53_zone.main.arn
        Condition = {
          "ForAllValues:StringEquals" = {
                        "route53:ChangeResourceRecordSetsNormalizedRecordNames" = flatten([
              for h in ["weather", "argocd"] : [
                "${h}.${trimsuffix(var.domain_name, ".")}",
                "external-dns-a-${h}.${trimsuffix(var.domain_name, ".")}",
                "external-dns-aaaa-${h}.${trimsuffix(var.domain_name, ".")}",
              ]
            ])
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListResourceRecordSets"
        ]
        Resource = data.aws_route53_zone.main.arn
      }
    ]
  })
}