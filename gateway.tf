resource "aws_security_group" "gateway_sg" {
  name        = "flipflop-gateway-sg"
  description = "Public routing access for API Gateway"
  vpc_id      = data.aws_vpc.default_network.id

  # Public inbound traffic for the API gateway endpoint
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.my_home_ip}/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_home_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "api_gateway" {
  ami                  = var.ami_id
  instance_type        = "t3.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.gateway_sg.name]
  iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install java-17-amazon-corretto-headless -y
              mkdir -p /app
              aws s3 cp s3://flipflopbucket/flipflop-api-gateway.jar /app/flipflop-api-gateway.jar
              nohup java -jar /app/flipflop-api-gateway.jar > /app/gateway.log 2>&1 &
              EOF

  tags = { Name = "flipflop-api-gateway" }
}

output "gateway_public_ip" {
  value = aws_instance.api_gateway.public_ip
}