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
resource "aws_instance" "flipflop-account-details-service" {
  ami                  = var.ami_id
  instance_type        = "t2.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.microservices_sg.name]
  iam_instance_profile = "flipflop-service-role"

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install java-21-amazon-corretto-headless jq aws-cli -y
              mkdir -p /app

              # Set backend database profile parameters using interpolation
              export MYSQL_DB_HOST="${aws_instance.db_server.private_ip}"

              # 2. Fetch the JSON block and extract the value of 'mypass' securely
              export MYSQL_DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "flipflop-db-credentials" --region ap-south-1 --query SecretString --output text | jq -r '.db_password')

              aws s3 cp s3://flip-flop-bucket/jars/flipflop-account-details-service/flipflop-account-details-service-0.0.1-SNAPSHOT.jar /app/flipflop-credit-card-service.jar
              nohup java -jar /app/flipflop-account-details-service.jar > /app/flipflop-account-details-service.log 2>&1 &
              EOF

  tags = { Name = "flipflop-account-details-service" }
}


resource "aws_instance" "flipflop-credit-card-service" {
  ami                  = var.ami_id
  instance_type        = "t2.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.microservices_sg.name]
  iam_instance_profile = "flipflop-service-role"

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install java-21-amazon-corretto-headless jq aws-cli -y
              mkdir -p /app
              export MYSQL_DB_HOST="${aws_instance.db_server.private_ip}"

              # 2. Fetch the JSON block and extract the value of 'mypass' securely
              export MYSQL_DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "flipflop-db-credentials" --region ap-south-1 --query SecretString --output text | jq -r '.db_password')

              export OFFERS_SERVICE_HOST="${aws_instance.flipflop-credit-card-offers-service.private_ip}"
              aws s3 cp s3://flip-flop-bucket/jars/flipflop-credit-card-service/flipflop-credit-card-service-0.0.1-SNAPSHOT.jar /app/flipflop-credit-card-service.jar
              nohup java -jar /app/flipflop-credit-card-service.jar > /app/flipflop-credit-card-service.log 2>&1 &
              EOF

  tags = { Name = "flipflop-credit-card-service" }
}


resource "aws_instance" "flipflop-credit-card-offers-service" {
  ami                  = var.ami_id
  instance_type        = "t2.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.microservices_sg.name]
  iam_instance_profile = "flipflop-service-role"

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install java-21-amazon-corretto-headless jq aws-cli -y
              mkdir -p /app
              export MYSQL_DB_HOST="${aws_instance.db_server.private_ip}"
              export MYSQL_DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "flipflop-db-credentials" --region ap-south-1 --query SecretString --output text | jq -r '.db_password')
              aws s3 cp s3://flip-flop-bucket/jars/flipflop-credit-card-offers-service/flipflop-credit-card-offers-service.jar /app/flipflop-credit-card-offers-service.jar
              nohup java -jar /app/flipflop-credit-card-offers-service.jar > /app/flipflop-credit-card-offers-service.log 2>&1 &
              EOF

  tags = { Name = "flipflop-credit-card-offers-service" }
}