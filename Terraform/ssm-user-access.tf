data "aws_iam_policy_document" "ssm_user_access" {
  statement {
    sid     = "StartSessionOnJenkinsAndGitLab"
    effect  = "Allow"
    actions = ["ssm:StartSession"]

    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = ["infinity-weather"]
    }

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Role"
      values   = ["jenkins", "gitlab", "monitoring"]
    }
  }

  statement {
    sid     = "AllowSessionManagerShell"
    effect  = "Allow"
    actions = ["ssm:StartSession"]

    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/SSM-SessionManagerRunShell",
      # AWS-owned document (no account ID in the ARN) used by the Prometheus tunnel
      "arn:aws:ssm:${var.aws_region}::document/AWS-StartPortForwardingSession"
    ]
  }

  statement {
    sid    = "ManageOwnSessions"
    effect = "Allow"

    actions = [
      "ssm:ResumeSession",
      "ssm:TerminateSession"
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/terraform-*"
    ]
  }
  statement {
    sid       = "ReadCloudTrailEvents"
    effect    = "Allow"
    actions   = ["cloudtrail:LookupEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "terraform_ssm_access" {
  name   = "infinity-weather-ssm-access"
  user   = "terraform"
  policy = data.aws_iam_policy_document.ssm_user_access.json
}
