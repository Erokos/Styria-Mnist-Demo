locals {

  env = {
    defaults = {
      project_name = "project_default"
      region_name = "region-default"
    }

    staging = {
      project_name = "erokos-staging"
      region_name = "eu-central-1"
    }

    production = {
      project_name = "erokos-production"
      region_name = "eu-west-1"
    }
  }

  workspace = "${merge(local.env["defaults"], local.env[terraform.workspace])}"
}

output "workspace" {
  value = "${terraform.workspace}"
}

output "project_name" {
  value = "${local.workspace["project_name"]}"
}

output "region_name" {
  value = "${local.workspace["region_name"]}"
}