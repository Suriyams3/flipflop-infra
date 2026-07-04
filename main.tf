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

# Isolated Security Group for the single API Gateway testing environment
resource "aws_security_group" "standalone_gateway_sg" {
  name        = "flipflop-standalone-gateway-sg"
  description = "Inbound boundary for testing the API Gateway hello endpoint"

  # SSH Access restricted to your home IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_home_ip}/32"]
  }

  # Spring Boot Application Access restricted to your home IP
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.my_home_ip}/32"]
  }

  # Outbound rules allowing the instance to download updates/packages from the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ENHANCED: User Data script to install Java 21, pull the JAR from S3, and execute it
locals {
  java_setup_script = <<-EOF
    #!/bin/bash
    # 1. Upgrade packages and install Java 21 Runtime (Corretto)
    sudo dnf update -y
    sudo dnf install -y java-21-amazon-corretto-devel

    # 2. Build dedicated deployment directory
    sudo mkdir -p /app
    sudo chown -R ec2-user:ec2-user /app
    cd /app

    # 3. Download the target gateway microservice JAR from your private S3 bucket
    # Note: If your AMI does not have aws-cli built-in, dnf install -y awscli can be added above
    aws s3 cp s3://flip-flop-bucket/flipflop-api-gateway/flipflop-api-gateway-0.0.1-SNAPSHOT.jar /app/flipflop-api-gateway.jar

    # 4. Spin up the Spring Boot app in the background, channeling runtime out to a log file
    nohup java -jar /app/flipflop-api-gateway.jar > /app/gateway.log 2>&1 &
  EOF
}

# Single Standalone API Gateway EC2 Instance
resource "aws_instance" "standalone_gateway" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.standalone_gateway_sg.id]
  key_name               = var.key_name
  
  # ENHANCED: Injected the S3 profile and startup logic parameters
  iam_instance_profile   = "flipflop-service-role"
  user_data              = local.java_setup_script

  tags = {
    Name = "flipflop-standalone-api-gateway"
  }
}

# Output the Public IP address so you can access your endpoint immediately
output "gateway_public_ip" {
  value       = aws_instance.standalone_gateway.public_ip
  description = "The public IP address to hit your /hello endpoint"
}
