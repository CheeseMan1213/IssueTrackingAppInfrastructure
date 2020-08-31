resource "aws_elastic_beanstalk_application" "issue-tracking-eb-app" {
  name        = "issue-tracking-eb-app"
  description = "issue-tracking-eb-app"
}

resource "aws_elastic_beanstalk_environment" "issue-tracking-eb-ev" {
  name                   = "issue-tracking-eb-ev"
  application            = aws_elastic_beanstalk_application.issue-tracking-eb-app.name
  description            = "My EB ENV for the my IssueTrackingApp (A Jira clone.)"
  solution_stack_name    = "64bit Amazon Linux 2018.03 v2.21.0 running Multi-container Docker 19.03.6-ce (Generic)"
  tier                   = "WebServer"
  wait_for_ready_timeout = "20m"
  # This line helps the AWS Elastic Beanstalk environment use the Dockerrun.aws.json file.
  version_label = aws_elastic_beanstalk_application_version.issue-tracking-eb-version.name

  /*
  These next things, these 'setting {}' objects:
  Are like when you create an elastic beanstalk environment
  from the AWS console, and you click "Configure more options"
  */

  # Gives VPC.
  setting {
    namespace = "aws:ec2:vpc"     # Must point to an AWS resource
    name      = "VPCId"           # //
    value     = module.vpc.vpc_id # //
  }
  # Assocciates my elastic IP.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = true
  }
  # Gives subnets.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${module.vpc.public_subnets[0]},${module.vpc.public_subnets[1]}" # Expects subnet IDs and not CIDRs.
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "aws-elasticbeanstalk-service-role"
    # value = "arn:aws:iam::475640621870:role/aws-elasticbeanstalk-service-role"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = "IssueTrackingApp_EC2_key"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.medium"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = "Time"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MinInstancesInService"
    value     = 0
  }

  /*
  NOTE = Terraform keeps on thinking that it needs to fix the "version_label" when it does
  not. I am adding this "lifecycle {}" block in order to have Terraform ignore all changes
  to the elastic beanstalk env.
  */
  lifecycle {
    ignore_changes = all
  }

  tags = merge(local.common_tags, { Name_1 = "issueTracking-${local.env_name}_issue-tracking-eb-ev" })
}
# Creating S3 bucket for initial Dockerrun.aws.json file.
resource "aws_s3_bucket" "issue-tracking-eb-DockerRun" {
  bucket = "issue-tracking-eb-dockerrun"
  acl    = "private"

  versioning {
    enabled = true
  }
}
# Giving Dockerrun.aws.json file.
resource "aws_s3_bucket_object" "issue-tracking-eb-DockerRun-obj" {
  bucket = aws_s3_bucket.issue-tracking-eb-DockerRun.id
  key    = "beanstalk/Dockerrun.aws.json"
  source = "Elastic_Beanstalk_CLI_Root/Dockerrun.aws.json"
}
resource "aws_elastic_beanstalk_application_version" "issue-tracking-eb-version" {
  name        = "issue-tracking-eb-version"
  application = "issue-tracking-eb-app"
  description = "Application version created by Terraform."
  bucket      = aws_s3_bucket.issue-tracking-eb-DockerRun.id
  key         = aws_s3_bucket_object.issue-tracking-eb-DockerRun-obj.id
}
