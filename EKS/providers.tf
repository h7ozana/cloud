# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_version = ">= 1.6.6"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

provider "http" {}
