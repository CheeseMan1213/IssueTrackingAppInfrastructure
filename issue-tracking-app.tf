# Controls for the terraform version allowed to be used from the cli.
terraform {
  required_version = ">= 0.12.0"
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

provider "kubernetes" {
  version                = "~> 1.9"
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

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

data "aws_eks_cluster" "cluster" {
  name = module.my-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.my-cluster.cluster_id
}

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

  cidr            = var.network_address_space[terraform.workspace]
  azs             = slice(data.aws_availability_zones.available.names, 0, var.subnet_count[terraform.workspace])
  public_subnets  = data.template_file.public_cidrsubnet[*].rendered # Expects CIDRs
  private_subnets = []

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

module "my-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "12.1.0"
  cluster_name    = "IssueTracking${local.env_name}Cluster"
  cluster_version = "1.16"
  # It wants subnet IDs.
  subnets = flatten([module.vpc.public_subnets, module.vpc.private_subnets])
  vpc_id  = module.vpc.vpc_id

  worker_groups = [
    {
      instance_type = var.instance_size[terraform.workspace]
      asg_max_size  = 2
    }
  ]

  tags = merge(local.common_tags, { Name = "issue_tracking_app-${local.env_name}-cluster" })
}
