# Controls for the terraform version allowed to be used from the cli.
terraform {
  required_version = ">= 0.12.29"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  version    = "~> 2.66"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

provider "random" {
  version = "~> 2.2"
}

provider "template" {
  version = "~> 2.1"
}

# provider "kubernetes" {
#   version                = "~> 1.9"
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
#   token                  = data.aws_eks_cluster_auth.cluster.token
#   load_config_file       = false
# }

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

data "template_file" "public_cidrsubnet" {
  count = var.subnet_count[terraform.workspace]

  template = "$${cidrsubnet(vpc_cidr,8,current_count)}"

  vars = {
    vpc_cidr      = var.network_address_space[terraform.workspace]
    current_count = count.index
  }
}

# data "aws_eks_cluster" "cluster" {
#   name = module.my-cluster.cluster_id
# }

# data "aws_eks_cluster_auth" "cluster" {
#   name = module.my-cluster.cluster_id
# }

##################################################################################
# RESOURCES
##################################################################################

#Random ID
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  # The dash turning blue is not a big deal.
  name    = "issue_tracking_app-${local.env_name}-vpc"
  version = "2.44.0"

  cidr               = var.network_address_space[terraform.workspace]
  azs                = slice(data.aws_availability_zones.available.names, 0, var.subnet_count[terraform.workspace])
  public_subnets     = data.template_file.public_cidrsubnet[*].rendered # Expects CIDRs
  private_subnets    = []
  create_igw         = true
  enable_nat_gateway = true

  tags = local.common_tags
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.16.0"

  # Ugh, I had to make it all lowercase, else I got errors.
  identifier = "issuetrackingapp${local.env_name}db"

  engine            = "postgres"
  engine_version    = "12.3"
  instance_class    = var.db_size[terraform.workspace]
  allocated_storage = 5
  storage_encrypted = false

  name              = "issuetrackingapp${local.env_name}db"
  username          = var.databaseUserName
  password          = var.databasePassword
  port              = "5432"
  availability_zone = "us-east-1a"

  # iam_database_authentication_enabled = true

  vpc_security_group_ids = [aws_security_group.postgres-sg.id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # DB subnet group
  # subnet_id                 = module.vpc.public_subnets[0]
  # subnet_ids                = data.template_file.public_cidrsubnet[*].rendered # Expects subnet IDs and not CIDRs.
  subnet_ids                = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
  family                    = "postgres12"
  major_engine_version      = "12"
  final_snapshot_identifier = "final-snapshot-issue-tracking-app-${local.env_name}-postgres-db"
  deletion_protection       = false

  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-postgres-db" })
}

resource "aws_ecr_repository" "issue-tracking-ecr-frontend" {
  name                 = "issue-tracking-ecr-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "issue-tracking-ecr-backend" {
  name                 = "issue-tracking-ecr-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Postgres DB security group 
resource "aws_security_group" "postgres-sg" {
  name   = "postgres-sg"
  vpc_id = module.vpc.vpc_id

  # Database access from anywhere
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic out of the database
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    # self = true
  }

  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-postgres-sg" })
}

# EC2 instance security group 
resource "aws_security_group" "ec2_sg" {
  name   = "ec2_sg"
  vpc_id = module.vpc.vpc_id

  ingress { # 1
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # 2
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # 3
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic out of the EC2 instance.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}_ec2_sg" })
}

# module "my-cluster" {
#   source          = "terraform-aws-modules/eks/aws"
#   version         = "12.1.0"
#   cluster_name    = "IssueTracking${local.env_name}Cluster"
#   cluster_version = "1.16"
#   # It wants subnet IDs.
#   subnets                        = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
#   vpc_id                         = module.vpc.vpc_id
#   cluster_endpoint_public_access = true

#   worker_groups = [
#     {
#       # instance_type = var.instance_size[terraform.workspace]
#       instance_type = "t2.medium"
#       # asg_max_size  = 2
#       # instance_type = "m4.large"
#       asg_max_size = 5
#     }
#   ]

#   tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-cluster" })
# }

/*
    This will be a "roll my own" "production like" enviornment EC2 instance.
    I am doing this because I had trouble with EKS, and ECS, and the load balancer being forced
    on me.
*/
module "production_like_EC2_1" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.15.0"

  name           = "production_like_EC2_1"
  instance_count = 1

  ami                         = "ami-0332883b0fc77c4c7"
  instance_type               = "t2.medium" # 2 CPU and 4 RAM
  key_name                    = "IssueTrackingApp_EC2_key"
  monitoring                  = true
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  subnet_id                   = module.vpc.public_subnets[0]
  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 30
    },
  ]

  tags = merge(local.common_tags, { Name = "issueTracking-${local.env_name}_production_like_EC2_1" })
}

resource "aws_eip_association" "eip_assoc" {
  # 'instance_id' needs to be accessed as an array, because I am using the module, not the resource.
  instance_id   = module.production_like_EC2_1.id[0]
  allocation_id = "eipalloc-088b4ae5c94d86337"
}
