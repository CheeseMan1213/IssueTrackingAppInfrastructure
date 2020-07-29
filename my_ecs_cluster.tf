# locals {
#   user_data = <<EOF
# #!/bin/bash
# echo "ECS_CLUSTER=issue-tracking-development-ecs-cluster" >> /etc/ecs/ecs.config
# EOF
# }

# # ECS instance security group 
# resource "aws_security_group" "ecs_ec2_sg" {
#   name   = "ecs_ec2_sg"
#   vpc_id = module.vpc.vpc_id

#   ingress { # 1
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress { # 3
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress { # 5
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # Allow all traffic out of the EC2 instance.
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}_ecs_ec2_sg" })
# }

# resource "aws_cloudwatch_log_group" "frontend_task_5" {
#   name = "frontend_task_5"

#   tags = merge(local.common_tags, { Name = "issueTracking-${local.env_name}_log_group" })
#   # tags = merge(local.common_tags, { Name })
# }

# resource "aws_iam_instance_profile" "ecsInstanceProfile" {
#   name = "ecsInstanceProfile"
#   role = "ecsInstanceRole"
# }

# module "ecs_instance_1" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "~> 2.15.0"

#   name           = "issue_tracking_app-${local.env_name}_ecs_instance_1"
#   instance_count = 1

#   ami                    = "ami-0c68bcf8472e9a9d3"
#   instance_type          = "m4.large"
#   key_name               = "IssueTrackingApp_EC2_key"
#   monitoring             = true
#   vpc_security_group_ids = [aws_security_group.ecs_ec2_sg.id]
#   subnet_id              = module.vpc.public_subnets[0]
#   # subnet_ids           = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
#   iam_instance_profile = aws_iam_instance_profile.ecsInstanceProfile.name
#   user_data_base64     = base64encode(local.user_data)
#   root_block_device = [
#     {
#       volume_type = "gp2"
#       volume_size = 30
#     },
#   ]

#   tags = merge(local.common_tags, { Name = "issueTracking-${local.env_name}_ecs-instance_1" })
# }

# resource "aws_ecs_task_definition" "frontend_task_5" {
#   family                   = "frontend_task_5"
#   requires_compatibilities = ["EC2"]
#   network_mode             = "host" # valid choices are: none, bridge, awsvpc, or host
#   // task_role_arn = "value"
#   execution_role_arn = "arn:aws:iam::475640621870:role/ecsTaskExecutionRole"
#   # cpu                = 256 // 0.25 vCPU
#   # memory             = 512

#   container_definitions = <<EOF
# [
#   {
#     "name": "frontend_task_5",
#     "image": "475640621870.dkr.ecr.us-east-1.amazonaws.com/issue-tracking-ecr-frontend:latest",
#     "cpu": 256,
#     "memory": 512,
#     "essential": true,
#     "portMappings": [
#       {
#         "containerPort": 80,
#         "hostPort": 80
#       }
#     ],
#     "logConfiguration": {
#       "logDriver": "awslogs",
#       "options": {
#         "awslogs-group": "${aws_cloudwatch_log_group.frontend_task_5.name}",
#         "awslogs-region": "us-east-1",
#         "awslogs-stream-prefix": "frontend_task_5"
#       }
#     }
#   }
# ]
# EOF
# }

# resource "aws_ecs_task_definition" "backend_task_2" {
#   family                   = "backend_task_2"
#   requires_compatibilities = ["EC2"]
#   network_mode             = "awsvpc" # valid choices are: none, bridge, awsvpc, or host
#   // task_role_arn = "value"
#   execution_role_arn = "arn:aws:iam::475640621870:role/ecsTaskExecutionRole"
#   # cpu                = 256 // 0.25 vCPU
#   # memory             = 512

#   container_definitions = <<EOF
# [
#   {
#     "name": "backend_task_2",
#     "image": "475640621870.dkr.ecr.us-east-1.amazonaws.com/issue-tracking-ecr-backend:latest",
#     "cpu": 256,
#     "memory": 512,
#     "essential": true,
#     "portMappings": [
#       {
#         "containerPort": 8080,
#         "hostPort": 8080
#       }
#     ]
#   }
# ]
# EOF
# }

# resource "aws_ecs_service" "frontend_service" {
#   name    = "frontend_service"
#   cluster = module.ecs.this_ecs_cluster_id
#   # task_definition = aws_ecs_task_definition.frontend_task_3.arn
#   task_definition = aws_ecs_task_definition.frontend_task_5.family
#   launch_type     = "EC2"
#   // I got an error saying that services only needs the IAM role if there is a load balancer.
#   // However, do not comment this back in if your task definition uses the awsvpc network mode.
#   // iam_role = "arn:aws:iam::475640621870:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"

#   desired_count = 1

#   deployment_maximum_percent         = 100
#   deployment_minimum_healthy_percent = 0

#   network_configuration {
#     security_groups = [module.vpc.default_security_group_id]
#     subnets         = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
#     # Must be commented out when launch type is EC2.
#     # assign_public_ip = true
#   }

#   # load_balancer {
#   #   target_group_arn = module.alb.target_group_arns[0]
#   #   container_name   = "frontend_task_3"
#   #   container_port   = 80
#   # }

#   deployment_controller {
#     type = "ECS" // Valid values: CODE_DEPLOY, ECS, EXTERNAL. Default: ECS
#   }
# }

# resource "aws_ecs_service" "backend_service" {
#   name    = "backend_service"
#   cluster = module.ecs.this_ecs_cluster_id
#   # task_definition = aws_ecs_task_definition.backend_task_1.arn
#   task_definition = aws_ecs_task_definition.backend_task_2.family
#   launch_type     = "EC2"
#   // I got an error saying that services only need the IAM role if there is a load balancer.
#   // iam_role        = "arn:aws:iam::475640621870:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"

#   desired_count = 1

#   deployment_maximum_percent         = 100
#   deployment_minimum_healthy_percent = 0

#   network_configuration {
#     security_groups = [module.vpc.default_security_group_id]
#     subnets         = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
#     # Must be commented out when launch type is EC2.
#     # assign_public_ip = true
#   }

#   deployment_controller {
#     type = "ECS" // Valid values: CODE_DEPLOY, ECS, EXTERNAL. Default: ECS
#   }
# }

# module "ecs" {
#   source  = "terraform-aws-modules/ecs/aws"
#   version = "2.3.0"

#   name = "issue-tracking-${local.env_name}-ecs-cluster"

#   tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-cluster" })
# }
