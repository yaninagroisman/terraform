data "aws_iam_policy_document" "ssm_user_access" {
  statement {
    sid     = "StartSessionOnJenkinsAndGitLab"
    effect  = "Allow"
    actions = ["ssm:StartSession"]

    resources = [
      "arn:aws:ec2:eu-north-1:060941289583:instance/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = ["infinity-weather"]
    }

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Role"
      values   = ["jenkins", "gitlab"]
    }
  }

  statement {
    sid     = "AllowSessionManagerShell"
    effect  = "Allow"
    actions = ["ssm:StartSession"]

    resources = [
      "arn:aws:ssm:eu-north-1:060941289583:document/SSM-SessionManagerRunShell"
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
      "arn:aws:ssm:eu-north-1:060941289583:session/terraform-*"
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
