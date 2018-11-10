terraform {
  backend "s3" {
    bucket = "name_of_your_bucket"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Use the AWS module for VPCs
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "styria-example"

  cidr = "10.10.0.0/16"

  azs             = ["us-east-1b", "us-east-1c"]
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.3.0/24", "10.10.4.0/24"]

  enable_nat_gateway = true

  tags = {
    Owner       = "user"
    Environment = "terraform.workspace"
    Name        = "teffaform vpc styria"
  }
}
