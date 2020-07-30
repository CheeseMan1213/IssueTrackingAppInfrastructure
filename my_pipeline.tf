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
