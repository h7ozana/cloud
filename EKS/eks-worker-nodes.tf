# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes
#

#노드 role 생성
resource "aws_iam_role" "ohNODE" {
  name = "terraform-eks-ohNODE"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

#정책 추가
resource "aws_iam_role_policy_attachment" "ohNODE-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ohNODE.name
}

resource "aws_iam_role_policy_attachment" "ohNODE-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ohNODE.name
}

resource "aws_iam_role_policy_attachment" "ohNODE-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ohNODE.name
}

#노드 그룹 생성
resource "aws_eks_node_group" "ohNODE" {
  cluster_name    = aws_eks_cluster.ohCluster.name
  node_group_name = "ohNODE"
  node_role_arn   = aws_iam_role.ohNODE.arn
  subnet_ids      = aws_subnet.ohPrivateSN[*].id

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.ohNODE-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.ohNODE-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.ohNODE-AmazonEC2ContainerRegistryReadOnly,
  ]
  tags = {
    "Name" = "${aws_eks_cluster.ohCluster.name}-ohNODE."
  }
}
