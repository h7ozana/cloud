#새 role 생성

resource "aws_iam_role" "ohCluster" {
  name = "terraform-eks-ohCluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
# role에 정책 추가
resource "aws_iam_role_policy_attachment" "ohCluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.ohCluster.name
}

resource "aws_iam_role_policy_attachment" "ohCluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.ohCluster.name
}

#보안그룹 생성
resource "aws_security_group" "ohCluster" {
  name        = "terraform-eks-ohCluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.ohVpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-cluster SG"
  }
}

resource "aws_security_group_rule" "ohCluster-ingress-workstation-https" {
  cidr_blocks       = [local.workstation-external-cidr]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ohCluster.id
  to_port           = 443
  type              = "ingress"
}

#클러스터 생성
resource "aws_eks_cluster" "ohCluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.ohCluster.arn

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    security_group_ids = [aws_security_group.ohCluster.id]
    subnet_ids         = aws_subnet.ohPublicSN[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.ohCluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.ohCluster-AmazonEKSVPCResourceController,
  ]
}
