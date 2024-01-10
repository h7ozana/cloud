# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "aws_region" {
  default = "ap-northeast-2"
}

variable "cluster_name" {
  default = "ohCluster"
  type    = string
}
