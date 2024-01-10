terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-northeast-2"
}

# VPC 생성
resource "aws_vpc" "ohVPC" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ohVPC"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "ohIGW" {
  tags = {
    Name = "ohIGW"
  }
}

# VPC에 인터넷 게이트웨이 연결
resource "aws_internet_gateway_attachment" "ohIGWAttachment" {
  vpc_id              = aws_vpc.ohVPC.id
  internet_gateway_id = aws_internet_gateway.ohIGW.id
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "ohPublicSN" {
  count = 2

  vpc_id                  = aws_vpc.ohVPC.id
  cidr_block              = element(["10.0.0.0/24", "10.0.1.0/24"], count.index)
  availability_zone       = element(["ap-northeast-2a", "ap-northeast-2c"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "ohPublic-SN-${count.index + 1}"
  }
}

# # 프라이빗 서브넷 생성
# resource "aws_subnet" "ohPrivateSN" {
#   count = 4

#   vpc_id            = aws_vpc.ohVPC.id
#   cidr_block        = element(["10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"], count.index)
#   availability_zone = element(["ap-northeast-2a", "ap-northeast-2c"], count.index % 2)

#   tags = {
#     Name = "ohPrivate-SN-${count.index + 1}"
#   }
# }

# 라우팅 테이블 생성
resource "aws_route_table" "ohPublicRT" {
  vpc_id = aws_vpc.ohVPC.id
  tags = {
    Name = "ohPublic-RT"
  }
}

resource "aws_route_table" "ohPrivateRT" {
  vpc_id = aws_vpc.ohVPC.id
  tags = {
    Name = "ohPrivate-RT"
  }
}

# 라우트 생성
resource "aws_route" "ohPublicRoute" {
  route_table_id         = aws_route_table.ohPublicRT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ohIGW.id
}

# # NAT 게이트웨이 생성
# resource "aws_eip" "ohNATGatewayEIP" {
#   domain = "vpc"
# }

# resource "aws_nat_gateway" "ohNATGateway" {
#   allocation_id = aws_eip.ohNATGatewayEIP.id
#   subnet_id     = aws_subnet.ohPublicSN[1].id #두 번째 퍼블릭 서브넷 참조
# }

# resource "aws_route" "ohPrivateRoute" {
#   route_table_id         = aws_route_table.ohPrivateRT.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id         = aws_nat_gateway.ohNATGateway.id
# }

# 서브넷과 라우팅 테이블 연결
resource "aws_route_table_association" "ohPublicSubnetAssociation" {
  count = 2

  subnet_id      = element(aws_subnet.ohPublicSN.*.id, count.index)
  route_table_id = aws_route_table.ohPublicRT.id
}

# resource "aws_route_table_association" "ohPrivateSubnetAssociation" {
#   count = 4

#   subnet_id      = element(aws_subnet.ohPrivateSN.*.id, count.index)
#   route_table_id = aws_route_table.ohPrivateRT.id
# }

# SG 생성
resource "aws_security_group" "oh_bastion_sg" {
  name        = "ohBastionSG"
  description = "Enable SSH access"
  vpc_id      = aws_vpc.ohVPC.id
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ohBastionSG"
  }
}
resource "aws_security_group" "oh_alb_sg" {
  name        = "ohALBSG"
  description = "Enable SSH, HTTP access"
  vpc_id      = aws_vpc.ohVPC.id
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ohALBSG"
  }
}
resource "aws_security_group" "oh_private_sg" {
  name        = "ohPrivateSG"
  description = "Allow all inbound traffic from ohPublicSG"
  vpc_id      = aws_vpc.ohVPC.id
  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = [aws_security_group.oh_alb_sg.id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.oh_bastion_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ohPrivateSG"
  }
}
resource "aws_security_group" "oh_rds_sg" {
  name        = "ohRDSSG"
  description = "RDS in and out"
  vpc_id      = aws_vpc.ohVPC.id
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = [aws_security_group.oh_private_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ohRDSSG"
  }
}

# Bastion EC2 생성
resource "aws_instance" "oh_bastion" {
  ami           = var.latest_ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name_1

  subnet_id                   = aws_subnet.ohPublicSN[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.oh_bastion_sg.id]

  tags = {
    Name = "ohBastion"
  }

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install nginx git -y
systemctl start nginx
systemctl enable nginx
rm -rf /usr/share/nginx/html/*
git clone https://github.com/h7ozana/html
mv -f /html/* /usr/share/nginx/html
systemctl restart nginx
EOF
}

# #서브넷 그룹 설정
# resource "aws_db_subnet_group" "oh_subnet_group" {
#   description = "SubnetGroup for Maria DB RDS"
#   subnet_ids = [
#     aws_subnet.ohPrivateSN[2].id,
#     aws_subnet.ohPrivateSN[3].id
#   ]
#   tags = {
#     Name = "ohSubnetGroup"
#   }
# }

# #시작 템플릿 생성
# resource "aws_launch_template" "oh_launch_template" {
#   name = "oh_launch_template"

#   image_id               = var.latest_ami_id
#   instance_type          = "t2.micro"
#   key_name               = var.key_name_2
#   vpc_security_group_ids = [aws_security_group.oh_private_sg.id]

#   user_data = base64encode(<<EOF
# #!/bin/bash
# # Install APM for Web Server
# yum install -y mariadb* php httpd php-mysqlnd
# systemctl enable mariadb httpd
# systemctl start httpd mariadb
# hostname ohWeb
# echo "<h1>Super Shy</h1>" > /var/www/html/index.html
# systemctl restart httpd
# EOF
#   )
# }

# #오토스케일링 설정
# resource "aws_autoscaling_group" "ohAutoScalingGroup" {
#   min_size         = 2
#   max_size         = 4
#   desired_capacity = 2
#   vpc_zone_identifier = [
#     aws_subnet.ohPrivateSN[0].id,
#     aws_subnet.ohPrivateSN[1].id,
#   ]

#   launch_template {
#     id      = aws_launch_template.oh_launch_template.id
#     version = aws_launch_template.oh_launch_template.latest_version
#   }

#   tag {
#     key                 = "Name"
#     value               = "ohASG"
#     propagate_at_launch = true
#   }

#   health_check_type         = "EC2"
#   health_check_grace_period = 300
#   target_group_arns         = [aws_lb_target_group.alb_target_group.arn]
# }

# resource "aws_autoscaling_policy" "oh_scale_out_policy" {
#   name                   = "ohScaleOutPolicy"
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300
#   scaling_adjustment     = 1
#   autoscaling_group_name = aws_autoscaling_group.ohAutoScalingGroup.name
# }

# #ALB생성
# resource "aws_lb" "application_load_balancer" {
#   internal           = false
#   load_balancer_type = "application"
#   subnets            = [aws_subnet.ohPublicSN[0].id, aws_subnet.ohPublicSN[1].id]
#   security_groups    = [aws_security_group.oh_alb_sg.id]

#   tags = {
#     Name = "ohALB"
#   }
# }

# resource "aws_lb_listener" "alb_listener" {
#   load_balancer_arn = aws_lb.application_load_balancer.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.alb_target_group.arn
#   }
# }

# resource "aws_lb_target_group" "alb_target_group" {
#   name     = "ohALBTargetGroup"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.ohVPC.id

#   health_check {
#     interval            = 300
#     timeout             = 120
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   stickiness {
#     enabled         = true
#     type            = "lb_cookie"
#     cookie_duration = 30
#   }
# }

# # RDS 생성
# resource "aws_db_instance" "oh_rds" {
#   identifier             = "ohrds1"
#   db_name                = "newjeans"
#   instance_class         = "db.t3.micro"
#   engine                 = "mariadb"
#   engine_version         = "10.6.14"
#   username               = "newjeans"
#   password               = "newjeans"
#   allocated_storage      = 20
#   db_subnet_group_name   = aws_db_subnet_group.oh_subnet_group.name
#   vpc_security_group_ids = [aws_security_group.oh_rds_sg.id]
#   # 스냅샷 현재 스킵 상태 final_snapshot_identifier = "oh-rds-final-snapshot"
#   skip_final_snapshot = true
# }
