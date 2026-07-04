resource "aws_security_group" "microservices_sg" {
  name        = "flipflop-apps-sg"
  description = "Security rules for back-end microservices"
  vpc_id      = data.aws_vpc.default_network.id

  # Allow all internal communication from within the VPC network
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default_network.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Service 1: Account Service
resource "aws_instance" "account_service" {
  ami                  = var.ami_id
  instance_type        = "t3.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.microservices_sg.name]
  iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install java-17-amazon-corretto-headless -y
              mkdir -p /app

              # Set backend database profile parameters using interpolation
              export DB_HOST="${aws_instance.db_server.private_ip}"

              aws s3 cp s3://flipflopbucket/account-service.jar /app/account-service.jar
              nohup java -jar /app/account-service.jar > /app/account.log 2>&1 &
              EOF

  tags = { Name = "flipflop-account-service" }
}

# Service 2: Inventory Service
resource "aws_instance" "inventory_service" {
  ami                  = var.ami_id
  instance_type        = "t3.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.microservices_sg.name]
  iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install java-17-amazon-corretto-headless -y
              mkdir -p /app
              export DB_HOST="${aws_instance.db_server.private_ip}"

              aws s3 cp s3://flipflopbucket/inventory-service.jar /app/inventory-service.jar
              nohup java -jar /app/inventory-service.jar > /app/inventory.log 2>&1 &
              EOF

  tags = { Name = "flipflop-inventory-service" }
}

# Service 3: Order Service
resource "aws_instance" "order_service" {
  ami                  = var.ami_id
  instance_type        = "t3.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.microservices_sg.name]
  iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install java-17-amazon-corretto-headless -y
              mkdir -p /app
              export DB_HOST="${aws_instance.db_server.private_ip}"

              aws s3 cp s3://flipflopbucket/order-service.jar /app/order-service.jar
              nohup java -jar /app/order-service.jar > /app/order.log 2>&1 &
              EOF

  tags = { Name = "flipflop-order-service" }
}