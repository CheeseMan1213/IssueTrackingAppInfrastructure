resource "aws_ecs_task_definition" "frontend_task_3" {
  family                   = "frontend_task_3"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  // task_role_arn = "value"
  execution_role_arn = "arn:aws:iam::475640621870:role/ecsTaskExecutionRole"
  cpu                = 1024 // 1 vCPU
  memory             = 2048

  container_definitions = <<EOF
[
  {
    "name": "frontend_task_3",
    "image": "475640621870.dkr.ecr.us-east-1.amazonaws.com/issue-tracking-ecr-repo:latest",
    "cpu": 1024,
    "memory": 2048,
    "essential": true
  }
]
EOF
}

resource "aws_ecs_task_definition" "backend_task_1" {
  family                   = "backend_task_1"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  // task_role_arn = "value"
  execution_role_arn = "arn:aws:iam::475640621870:role/ecsTaskExecutionRole"
  cpu                = 1024 // 1 vCPU
  memory             = 2048

  container_definitions = <<EOF
[
  {
    "name": "backend_task_1",
    "image": "475640621870.dkr.ecr.us-east-1.amazonaws.com/issue-tracking-ecr-backend:latest",
    "cpu": 1024,
    "memory": 2048,
    "essential": true
  }
]
EOF
}

resource "aws_ecs_service" "frontend_service" {
  name    = "frontend_service"
  cluster = module.ecs.this_ecs_cluster_id
  # task_definition = aws_ecs_task_definition.frontend_task_3.arn
  task_definition = aws_ecs_task_definition.frontend_task_3.family
  launch_type     = "FARGATE"
  // I got an error saying that services only need the IAM role if there is a load balancer.
  // iam_role        = "arn:aws:iam::475640621870:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"

  desired_count = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
    security_groups  = [module.vpc.default_security_group_id]
    subnets          = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "backend_service" {
  name    = "backend_service"
  cluster = module.ecs.this_ecs_cluster_id
  # task_definition = aws_ecs_task_definition.backend_task_1.arn
  task_definition = aws_ecs_task_definition.backend_task_1.family
  launch_type     = "FARGATE"
  // I got an error saying that services only need the IAM role if there is a load balancer.
  // iam_role        = "arn:aws:iam::475640621870:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"

  desired_count = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
    security_groups  = [module.vpc.default_security_group_id]
    subnets          = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
    assign_public_ip = true
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "2.3.0"

  name = "issue-tracking-${local.env_name}-ecs-cluster"

  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-cluster" })
}
