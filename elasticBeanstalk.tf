resource "aws_elastic_beanstalk_application" "issue-tracking-eb-app" {
  name        = "issue-tracking-eb-app"
  description = "issue-tracking-eb-app"
}

/*
Helpful links:
https://github.com/cloudposse/terraform-aws-elastic-beanstalk-environment/blob/master/variables.tf
https://github.com/cloudposse/terraform-aws-elastic-beanstalk-environment/blob/master/main.tf
*/
resource "aws_elastic_beanstalk_environment" "issue-tracking-eb-ev" {
  name                   = "issue-tracking-eb-ev"
  application            = aws_elastic_beanstalk_application.issue-tracking-eb-app.name
  description            = "My EB ENV for the my IssueTrackingApp (A Jira clone.)"
  solution_stack_name    = "64bit Amazon Linux 2018.03 v2.22.0 running Multi-container Docker 19.03.6-ce (Generic)"
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
    name      = "VPCId"           # Also from a finite list. See internet.
    value     = module.vpc.vpc_id # //
  }
  # Assocciates a elastic IP.
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
  setting { # value     = "SingleInstance"
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 1
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 1
  }
  ### Listeners BEGIN
  setting { # 1
    namespace = "aws:elb:listener:80"
    name      = "ListenerEnabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elb:listener:80"
    name      = "ListenerProtocol"
    value     = "HTTP"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "LoadBalancerHTTPPort"
    value     = 80
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "LoadBalancerPortProtocol"
    value     = "HTTP"
  }
  setting {
    namespace = "aws:elb:listener:80"
    name      = "InstancePort"
    value     = 80
  }

  setting { # 2
    namespace = "aws:elb:listener:443"
    name      = "ListenerEnabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elb:listener:443"
    name      = "ListenerProtocol"
    value     = "HTTPS"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "LoadBalancerHTTPSPort"
    value     = 443
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "LoadBalancerSSLPortProtocol"
    value     = "HTTPS"
  }
  setting {
    namespace = "aws:elb:listener:443"
    name      = "InstancePort"
    # value     = 443
    value = 80 ## Still needs to be 80 because this is the instance/applocation port
    ## and I only EXPOSE port 80 and 8080 in my Dockerfiles.
  }

  setting { # 3
    namespace = "aws:elb:listener:8080"
    name      = "ListenerProtocol"
    value     = "HTTP"
  }
  setting {
    namespace = "aws:elb:listener:8080"
    name      = "InstancePort"
    value     = 8080
  }
  ### Listeners END

  ### Processes BEGIN
  setting { # 1
    namespace = "aws:elasticbeanstalk:environment:process:frontendNotSecure"
    name      = "HealthCheckPath"
    value     = "/"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:frontendNotSecure"
    name      = "Port"
    value     = 80
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:frontendNotSecure"
    name      = "Protocol"
    value     = "HTTP"
  }

  setting { # 2
    namespace = "aws:elasticbeanstalk:environment:process:frontendSecure"
    name      = "HealthCheckPath"
    value     = "/"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:frontendSecure"
    name      = "Port"
    value     = 443
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:frontendSecure"
    name      = "Protocol"
    value     = "HTTPS"
  }

  setting { # 3
    namespace = "aws:elasticbeanstalk:environment:process:backendNotSecure"
    name      = "HealthCheckPath"
    value     = "/"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:backendNotSecure"
    name      = "Port"
    value     = 8080
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:backendNotSecure"
    name      = "Protocol"
    value     = "HTTP"
  }
  ### Processes END

  # setting { # Commenting out because undoing Cloudposse advice because no longer SingleInstance
  #   namespace = "aws:autoscaling:updatepolicy:rollingupdate"
  #   name      = "RollingUpdateType"
  #   value     = "Time"
  # }
  # setting { # Commenting out because undoing Cloudposse advice because no longer SingleInstance
  #   namespace = "aws:autoscaling:updatepolicy:rollingupdate"
  #   name      = "MinInstancesInService"
  #   value     = 0
  # }
  # setting {
  #   namespace = "aws:elb:listener:443"
  #   name      = "SSLCertificateId"
  #   # value     = "3fc22192-ba8a-4936-a1f7-b7e3811c31c8"
  #   value = "arn:aws:acm:us-east-1:475640621870:certificate/3fc22192-ba8a-4936-a1f7-b7e3811c31c8"
  # }

  /*
  NOTE = Terraform keeps on thinking that it needs to fix the "version_label" when it does
  not. I am adding this "lifecycle {}" block in order to have Terraform ignore all changes
  to the elastic beanstalk env.
  */
  # lifecycle {
  #   ignore_changes = all
  # }

  tags = merge(local.common_tags, { Name_1 = "issueTracking-${local.env_name}_issue-tracking-eb-ev" })
}
# Creating S3 bucket for initial Dockerrun.aws.json file.
resource "aws_s3_bucket" "issue_tracking_eb_DockerRun" {
  bucket = "issue-tracking-eb-dockerrun"
  acl    = "private"

  versioning {
    enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "dockerrun" {
  bucket = aws_s3_bucket.issue_tracking_eb_DockerRun.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Giving Dockerrun.aws.json file.
resource "aws_s3_bucket_object" "issue_tracking_eb_DockerRun_obj" {
  bucket = aws_s3_bucket.issue_tracking_eb_DockerRun.id
  key    = "beanstalk/Dockerrun.aws.json"
  source = "Elastic_Beanstalk_CLI_Root/Dockerrun.aws.json"
}
resource "aws_elastic_beanstalk_application_version" "issue-tracking-eb-version" {
  name        = "issue-tracking-eb-version"
  application = "issue-tracking-eb-app"
  description = "Application version created by Terraform."
  bucket      = aws_s3_bucket.issue_tracking_eb_DockerRun.id
  key         = aws_s3_bucket_object.issue_tracking_eb_DockerRun_obj.id
}
