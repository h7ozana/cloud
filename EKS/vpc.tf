# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table


resource "aws_vpc" "ohVpc" {
  cidr_block = "20.0.0.0/16"

  tags = tomap({
    "Name"                                      = "terraform-eks-ohVpc",
    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
  })
}

resource "aws_subnet" "ohPublicSN" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "20.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.ohVpc.id

  tags = tomap({
    "Name"                                      = "terraform-eks-ohPublicSN-${count.index}",
    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
  })
}

resource "aws_internet_gateway" "ohIG" {
  vpc_id = aws_vpc.ohVpc.id

  tags = {
    Name = "terraform-eks-ohIG"
  }
}

resource "aws_route_table" "ohRT" {
  vpc_id = aws_vpc.ohVpc.id
  tags = {
    Name = "eks-ohPublicRT"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ohIG.id
  }
}

resource "aws_route_table_association" "ohRT" {
  count = 2

  subnet_id      = aws_subnet.ohPublicSN[count.index].id
  route_table_id = aws_route_table.ohRT.id
}

resource "aws_subnet" "ohPrivateSN" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = "20.0.${count.index + 2}.0/24"
  vpc_id            = aws_vpc.ohVpc.id

  tags = tomap({
    "Name"                                      = "terraform-eks-ohPrivateSN-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared",
  })
}

resource "aws_eip" "ohEIP" {
  domain = "vpc"
  tags = {
    Name = "eks-EIP"
  }
}

resource "aws_nat_gateway" "ohNAT" {
  allocation_id = aws_eip.ohEIP.id
  subnet_id     = aws_subnet.ohPublicSN[0].id
  tags = {
    Name = "eks-NAT"
  }
}

resource "aws_route_table" "ohPrivateRT" {
  vpc_id = aws_vpc.ohVpc.id

  tags = {
    Name = "eks-ohPrivateRT"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ohNAT.id
  }
}

resource "aws_route_table_association" "ohPrivateRT" {
  count = 2

  subnet_id      = aws_subnet.ohPrivateSN[count.index].id
  route_table_id = aws_route_table.ohPrivateRT.id
}
