# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Workstation External IP
# 클러스터에 접근할 수 있는 IP를 지정

data "http" "workstation-external-ip" {
  url = "http://ipv4.icanhazip.com"
}

# Override with variable or hardcoded value if necessary
locals {
  workstation-external-cidr = "${chomp(data.http.workstation-external-ip.response_body)}/32"
}
