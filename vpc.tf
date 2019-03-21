terraform {
  backend "s3" {
    bucket = "name_of_your_bucket"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "${local.workspace["region_name"]}"
}

data "aws_availability_zones" "azs" {
  provider = "${aws.local.workspace["region_name"]}"
}


# Use the AWS module for VPCs
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "styria-example"

  cidr = "10.10.0.0/16"

  azs             = ["${data.aws_availability_zones.azs.names[count.index]}"]
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.3.0/24", "10.10.4.0/24"]

  enable_nat_gateway = true

  tags = {
    Environment = "${terraform.workspace}"
    Name        = "erokos-${terraform.workspace}"
  }
}
