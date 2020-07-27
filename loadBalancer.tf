# # Application load balancer security group
# resource "aws_security_group" "issue-tracking-alb-sg" {
#   name   = "issue-tracking-alb-sg"
#   vpc_id = module.vpc.vpc_id

#   # HTTP access from anywhere.
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # HTTPS access from anywhere.
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # Allow all traffic out of the database.
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-alb-sg" })
# }

# module "alb" {
#   source  = "terraform-aws-modules/alb/aws"
#   version = "~> 5.6.0"

#   name = "issue-tracking-${local.env_name}-alb"

#   load_balancer_type = "application"

#   vpc_id          = module.vpc.vpc_id
#   subnets         = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
#   security_groups = [aws_security_group.issue-tracking-alb-sg.id]

#   #   access_logs = {
#   #     bucket = "my-alb-logs"
#   #   }

#   target_groups = [
#     {
#       name_prefix      = "pref-"
#       backend_protocol = "HTTP"
#       backend_port     = 80
#       target_type      = "ip"
#     },
#     {
#       name_prefix      = "pref2-"
#       backend_protocol = "HTTPS"
#       backend_port     = 443
#       target_type      = "ip"
#     }
#   ]

#   #   https_listeners = [
#   #     {
#   #       port               = 443
#   #       protocol           = "HTTPS"
#   #       certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
#   #       target_group_index = 0
#   #     }
#   #   ]

#   http_tcp_listeners = [
#     {
#       port               = 80
#       protocol           = "HTTP"
#       target_group_index = 0
#     }
#   ]

#   tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-loadBalancer" })
# }
