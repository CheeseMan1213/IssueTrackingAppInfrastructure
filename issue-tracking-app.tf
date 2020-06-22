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

##################################################################################
# RESOURCES
##################################################################################

#Random ID
resource "random_integer" "rand" {
  min = 10000
  max = 99999
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  # The dash truning blue is not a big deal.
  name    = "issue_tracking_app-${local.env_name}-vpc"
  version = "2.44.0"

  cidr            = var.network_address_space[terraform.workspace]
  azs             = slice(data.aws_availability_zones.available.names, 0, var.subnet_count[terraform.workspace])
  public_subnets  = data.template_file.public_cidrsubnet[*].rendered
  private_subnets = []

  tags = local.common_tags
}

//