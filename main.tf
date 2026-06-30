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

# User Data script execution block to automatically provision the Java 21 runtime engine
locals {
  java_setup_script = <<-EOF
    #!/bin/bash
    sudo dnf update -y
    sudo dnf install -y java-21-amazon-corretto-devel
  EOF
}

# Single Standalone API Gateway EC2 Instance
resource "aws_instance" "standalone_gateway" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.standalone_gateway_sg.id]
  key_name               = var.key_name
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
