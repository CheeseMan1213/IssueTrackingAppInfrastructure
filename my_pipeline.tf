resource "aws_iam_role" "issue-tracking-code-build-role" {
  name = "issue-tracking-code-build"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "issue-tracking-code-build-policy" {
  role = aws_iam_role.issue-tracking-code-build-role.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": [
        "arn:aws:ec2:us-east-1:475640621870:network-interface/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:Subnet": [
            "${module.vpc.public_subnet_arns[0]}",
            "${module.vpc.public_subnet_arns[1]}"
            ],
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
  # The resource itself.
}

# Second policy. This is an AWS managed one.
resource "aws_iam_role_policy_attachment" "issue-tracking-ecr-full-access" {
  role       = aws_iam_role.issue-tracking-code-build-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"

}

## The main thing we want at the monent is an AWS CodeBuild project.
# The rest of the resources in this file are for those.
resource "aws_codebuild_project" "issue-tracking-codebuild-frontend" {
  name          = "issue-tracking-codebuild-frontend"
  description   = "issue-tracking-codebuild-frontend"
  build_timeout = "60"
  service_role  = aws_iam_role.issue-tracking-code-build-role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # Required
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  # logs_config {
  #   cloudwatch_logs {
  #     group_name  = "log-group"
  #     stream_name = "log-stream"
  #   }

  source {
    type            = "GITHUB"
    location        = "https://github.com/CheeseMan1213/IssueTrackingAppFrontend.git"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "master"

  #   vpc_config {
  #     vpc_id = module.vpc.vpc_id

  #     # subnets = [
  #     #   "${aws_subnet.example1.id}",
  #     #   "${aws_subnet.example2.id}",
  #     # ]
  #     # It wants subnet IDs.
  #     subnets = flatten([module.vpc.public_subnets, module.vpc.private_subnets])

  #     security_group_ids = [
  #       "${aws_security_group.example1.id}",
  #       "${aws_security_group.example2.id}",
  #     ]
  #   }
  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-codebuild-frontend" })
}

resource "aws_codebuild_project" "issue-tracking-codebuild-backend" {
  name          = "issue-tracking-codebuild-backend"
  description   = "issue-tracking-codebuild-backend"
  build_timeout = "60"
  service_role  = aws_iam_role.issue-tracking-code-build-role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # Required
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/CheeseMan1213/IssueTrackingAppBackend.git"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "master"

  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-codebuild-backend" })
}

resource "aws_codebuild_webhook" "frontend_webhook" {
  project_name = aws_codebuild_project.issue-tracking-codebuild-frontend.name

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "master"
    }
  }
}

resource "aws_codebuild_webhook" "backend_webhook" {
  project_name = aws_codebuild_project.issue-tracking-codebuild-backend.name

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "master"
    }
  }
}

### BEGIN: Notification setup for frontend CodeBuild ###
resource "aws_cloudwatch_event_rule" "notify_frontend_build_rule" {
  name        = "notify_frontend_build_rule"
  description = "CodeBuild Build State Change"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codebuild"
  ],
  "detail-type": [
    "CodeBuild Build State Change"
  ],
  "detail": {
    "project-name": [
      "${aws_codebuild_project.issue-tracking-codebuild-frontend.name}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "notify_frontend_build_event_target" {
  rule      = aws_cloudwatch_event_rule.notify_frontend_build_rule.name
  target_id = "SendToSNS_frontend"
  arn       = aws_sns_topic.nofify_frontend_build_topic.arn
}

resource "aws_sns_topic" "nofify_frontend_build_topic" {
  name = "nofify_frontend_build_topic"
}

resource "aws_sns_topic_policy" "notify_frontend_build_policy" {
  arn    = aws_sns_topic.nofify_frontend_build_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy_frontend.json
}

data "aws_iam_policy_document" "sns_topic_policy_frontend" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = ["${aws_sns_topic.nofify_frontend_build_topic.arn}"]
  }
}

resource "aws_sns_topic_subscription" "nofify_frontend_build_subscription" {
  topic_arn            = aws_sns_topic.nofify_frontend_build_topic.arn
  protocol             = "sms"
  endpoint             = var.myPhoneNumber
  raw_message_delivery = false
}
## TODO: Manually add subscription to sns topic for email once resources are created.
## TL;DR reason: Not supported by Terraform; breaks the Terraform model

### END: Notification setup for frontend CodeBuild ###

### BEGIN: Notification setup for backend CodeBuild ###
resource "aws_cloudwatch_event_rule" "notify_backend_build_rule" {
  name        = "notify_backend_build_rule"
  description = "CodeBuild Build State Change"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codebuild"
  ],
  "detail-type": [
    "CodeBuild Build State Change"
  ],
  "detail": {
    "project-name": [
      "${aws_codebuild_project.issue-tracking-codebuild-backend.name}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "notify_backend_build_event_target" {
  rule      = aws_cloudwatch_event_rule.notify_backend_build_rule.name
  target_id = "SendToSNS_backend"
  arn       = aws_sns_topic.nofify_backend_build_topic.arn
}

resource "aws_sns_topic" "nofify_backend_build_topic" {
  name = "nofify_backend_build_topic"
}

resource "aws_sns_topic_policy" "notify_backend_build_policy" {
  arn    = aws_sns_topic.nofify_backend_build_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy_backend.json
}

data "aws_iam_policy_document" "sns_topic_policy_backend" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = ["${aws_sns_topic.nofify_backend_build_topic.arn}"]
  }
}

resource "aws_sns_topic_subscription" "nofify_backend_build_subscription" {
  topic_arn            = aws_sns_topic.nofify_backend_build_topic.arn
  protocol             = "sms"
  endpoint             = var.myPhoneNumber
  raw_message_delivery = false
}
## TODO: Manually add subscription to sns topic for email once resources are created.
## TL;DR reason: Not supported by Terraform; breaks the Terraform model

### END: Notification setup for backend CodeBuild ###

resource "aws_sns_sms_preferences" "update_sms_prefs" {
  monthly_spend_limit = 5 # USD $5.00
  // delivery_status_iam_role_arn = 
  delivery_status_success_sampling_rate = 100
  default_sender_id                     = "James"
  default_sms_type                      = "Promotional"
  // usage_report_s3_bucket = ""
}
