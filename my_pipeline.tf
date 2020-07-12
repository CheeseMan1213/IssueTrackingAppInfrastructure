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
# The rest of the resources in this file are for this one.
resource "aws_codebuild_project" "issue-tracking-codebuild" {
  name          = "issue-tracking-codebuild"
  description   = "issue-tracking-codebuild"
  build_timeout = "5"
  service_role  = aws_iam_role.issue-tracking-code-build-role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  #   cache {
  #     type     = "S3"
  #     location = "${aws_s3_bucket.example.bucket}"
  #   }

  # Required
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    # Optional
    # environment_variable {
    #   name  = "SOME_KEY1"
    #   value = "SOME_VALUE1"
    # }

    # Optional
    # environment_variable {
    #   name  = "SOME_KEY2"
    #   value = "SOME_VALUE2"
    #   type  = "PARAMETER_STORE"
    # }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

    # s3_logs {
    #   status   = "ENABLED"
    #   location = "${aws_s3_bucket.example.id}/build-log"
    # }
  }

  source {
    type = "GITHUB"
    # location        = "https://github.com/mitchellh/packer.git"
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

  #   tags = {
  #     Environment = "Test"
  #   }
  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-codebuild" })
}
