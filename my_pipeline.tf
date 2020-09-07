resource "aws_iam_role" "issue_tracking_codepipeline_role" {
  name = "issue_tracking_codepipeline_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "issue_tracking_codepipeline_policy" {
  role = aws_iam_role.issue_tracking_codepipeline_role.name

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Condition": {
                "StringEqualsIfExists": {
                    "iam:PassedToService": [
                        "cloudformation.amazonaws.com",
                        "elasticbeanstalk.amazonaws.com",
                        "ec2.amazonaws.com",
                        "ecs-tasks.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Action": [
                "codecommit:CancelUploadArchive",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetUploadArchiveStatus",
                "codecommit:UploadArchive"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:RegisterApplicationRevision"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codestar-connections:UseConnection"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "elasticbeanstalk:*",
                "ec2:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudwatch:*",
                "s3:*",
                "sns:*",
                "cloudformation:*",
                "rds:*",
                "sqs:*",
                "ecs:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "lambda:InvokeFunction",
                "lambda:ListFunctions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "opsworks:CreateDeployment",
                "opsworks:DescribeApps",
                "opsworks:DescribeCommands",
                "opsworks:DescribeDeployments",
                "opsworks:DescribeInstances",
                "opsworks:DescribeStacks",
                "opsworks:UpdateApp",
                "opsworks:UpdateStack"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:UpdateStack",
                "cloudformation:CreateChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:SetStackPolicy",
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "devicefarm:ListProjects",
                "devicefarm:ListDevicePools",
                "devicefarm:GetRun",
                "devicefarm:GetUpload",
                "devicefarm:CreateUpload",
                "devicefarm:ScheduleRun"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicecatalog:ListProvisioningArtifacts",
                "servicecatalog:CreateProvisioningArtifact",
                "servicecatalog:DescribeProvisioningArtifact",
                "servicecatalog:DeleteProvisioningArtifact",
                "servicecatalog:UpdateProduct"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:DescribeImages"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "states:DescribeExecution",
                "states:DescribeStateMachine",
                "states:StartExecution"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "appconfig:StartDeployment",
                "appconfig:StopDeployment",
                "appconfig:GetDeployment"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
  # The resource itself.
}

# Creating S3 bucket for pipeline.
/*
**NOTE = This is not the source bucket for the Dockerrun.aws.json file.
AWS CodePipeline needs a bucket for it to use to store artifacts that you
may never reference or care much for at the time, but it is still required.
*/
resource "aws_s3_bucket" "issue_tracking_pipeline_bucket" {
  bucket = "issue-tracking-pipeline-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "pipeline" {
  bucket = aws_s3_bucket.issue_tracking_pipeline_bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
/*
    Note = See this webpage for help:
    https://docs.aws.amazon.com/codepipeline/latest/userguide/reference-pipeline-structure.html#action-requirements
    AND
    Do not discount this page just because it is an AWS page. It did give me what I needed
    concerning the "configuration block" , so it could again.
*/
resource "aws_codepipeline" "issue_tracking_pipeline" {
  name     = "issue_tracking_pipeline"
  role_arn = aws_iam_role.issue_tracking_codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.issue_tracking_pipeline_bucket.bucket
    # region   = var.region
    type = "S3"
  }

  stage { # 1
    name = "Source"

    action { # 1
      name             = "Source_Frontend"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        Owner      = "CheeseMan1213"
        Repo       = "IssueTrackingAppFrontend"
        Branch     = "master"
        OAuthToken = var.github_token
      }
    }
    action { # 2
      name             = "Source_Backend"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceArtifact_2"]

      configuration = {
        Owner      = "CheeseMan1213"
        Repo       = "IssueTrackingAppBackend"
        Branch     = "master"
        OAuthToken = var.github_token
      }
    }
    action { # 3
      name             = "Source-Dockerrun.aws.json"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact_3"]

      configuration = {
        S3Bucket    = aws_s3_bucket.issue-tracking-eb-DockerRun.id
        S3ObjectKey = aws_s3_bucket_object.issue-tracking-eb-DockerRun-obj.id
      }
    }
  }
  stage { # 2
    name = "Build"

    action { # 1
      name             = "Build_Frontend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.issue-tracking-codebuild-frontend.name
      }
    }
  }
  stage { # 3
    name = "Build_2"

    action { # 1
      name             = "Build_Backend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact_2"]
      output_artifacts = ["BuildArtifact_2"]

      configuration = {
        ProjectName = aws_codebuild_project.issue-tracking-codebuild-backend.name
      }
    }
  }
  stage { # 4
    name = "Deploy"

    action { # 1
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      input_artifacts = ["SourceArtifact_3"]
      version         = "1"

      configuration = {
        ApplicationName = aws_elastic_beanstalk_application.issue-tracking-eb-app.name
        EnvironmentName = aws_elastic_beanstalk_environment.issue-tracking-eb-ev.name
      }
    }
  }
  /*
  NOTE = Terraform keeps on thinking that it needs to fix the "OAuthToken" when it does
  not. I am adding this "lifecycle {}" block in order to have Terraform ignore all changes
  to the pipeline.
  */
  # lifecycle {
  #   ignore_changes = all
  # }
}