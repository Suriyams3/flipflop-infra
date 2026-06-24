terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Automatically gets your home network's IP when you run it
data "http" "my_home_ip" {
  url = "https://checkip.amazonaws.com"
}

# 1. API Gateway Security Group (Allows your house to connect)
resource "aws_security_group" "gateway_sg" {
  name        = "flipflop-gateway-sg"
  description = "Public inbound traffic to API Gateway"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_home_ip.response_body)}/32"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_home_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Backend Microservices Security Group
resource "aws_security_group" "backend_sg" {
  name        = "flipflop-backend-sg"
  description = "Internal communications routing"

  ingress {
    from_port       = 8081
    to_port         = 8083
    protocol        = "tcp"
    security_groups = [aws_security_group.gateway_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows easy cross-ssh from your management node
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Isolated MySQL Database Security Group
resource "aws_security_group" "db_sg" {
  name        = "flipflop-db-sg"
  description = "Allows MySQL entry strictly from backend servers"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Shared IAM policy profile for the newly created instances
resource "aws_iam_role" "ec2_describe_role" {
  name = "flipflop-cluster-describe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_readonly" {
  role       = aws_iam_role.ec2_describe_role.name
  policy_arn = "arn:aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "flipflop-cluster-profile"
  role = aws_iam_role.ec2_describe_role.name
}

# 4. Creating the 4 Managed Instances (Excluding your current jump server)
resource "aws_instance" "api_gateway" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.gateway_sg.id]
  instance_profile       = aws_iam_instance_profile.ec2_profile.name
  tags                   = { Name = "flipflop-api-gateway" }
}

resource "aws_instance" "account_service" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  instance_profile       = aws_iam_instance_profile.ec2_profile.name
  tags                   = { Name = "flipflop-account-details-service" }
}

resource "aws_instance" "credit_card_service" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  instance_profile       = aws_iam_instance_profile.ec2_profile.name
  tags                   = { Name = "flipflop-credit-card-service" }
}

resource "aws_instance" "offers_service" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  instance_profile       = aws_iam_instance_profile.ec2_profile.name
  tags                   = { Name = "flipflop-offers-service" }
}

# 5th Instance: MySQL Engine
resource "aws_instance" "mysql_db" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  tags                   = { Name = "flipflop-mysql-db" }

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /etc/flipflop
              echo "MYSQL_DB_PASSWORD=${var.db_password}" > /etc/flipflop/db.env
              chmod 600 /etc/flipflop/db.env
              EOF
}

output "gateway_public_ip" {
  value = aws_instance.api_gateway.public_ip
}