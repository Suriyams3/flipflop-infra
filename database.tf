resource "aws_security_group" "db_sg" {
  name        = "flipflop-db-sg"
  description = "Internal database access controls"
  vpc_id      = data.aws_vpc.default_network.id

  # Restricts DB access tightly to internal VPC traffic components only
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default_network.cidr_block]
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

resource "aws_instance" "db_server" {
  ami                  = var.ami_id
  instance_type        = "t2.micro"
  key_name             = var.key_name
  security_groups      = [aws_security_group.db_sg.name]
  iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              dnf update -y
              dnf install -y mariadb-server
              systemctl start mariadb
              systemctl enable mariadb

              cat << 'SQL_EOF' > /tmp/setup.sql
              CREATE DATABASE IF NOT EXISTS flipflop_account_db;
              CREATE USER IF NOT EXISTS 'db_user'@'%' IDENTIFIED BY 'FlipFlopSecurePass123!';
              GRANT ALL PRIVILEGES ON flipflop_account_db.* TO 'db_user'@'%';
              FLUSH PRIVILEGES;
              USE flipflop_account_db;

              -- 1. Create the Independent Parent Table (ProfileDetails)
              CREATE TABLE IF NOT EXISTS profile_details (
                  account_number VARCHAR(255) NOT NULL,
                  first_name VARCHAR(100) NOT NULL,
                  last_name VARCHAR(100) NOT NULL,
                  age INT NOT NULL,
                  sex VARCHAR(20) NULL,
                  marital_status VARCHAR(50) NULL,
                  address VARCHAR(255) NULL,
                  phone_number VARCHAR(50) NOT NULL,
                  PRIMARY KEY (account_number)
              );

              -- 2. Create the Dependent Child Table (AccountDetails)
              CREATE TABLE IF NOT EXISTS account_details (
                  account_number VARCHAR(255) NOT NULL,
                  account_balance DECIMAL(38, 2) NOT NULL,
                  account_open_date DATE NOT NULL,
                  debit_card_number VARCHAR(255) NULL,
                  debit_card_expiry_date DATE NULL,
                  PRIMARY KEY (account_number),
                  CONSTRAINT fk_account_profile FOREIGN KEY (account_number)
                      REFERENCES profile_details(account_number) ON DELETE CASCADE
              );

              -- 1. Insert Profile Records First
              INSERT INTO profile_details (
                  account_number, first_name, last_name, age, sex, marital_status, address, phone_number
              ) VALUES
              ('ACC1001', 'John', 'Doe', 35, 'Male', 'Married', '123 Cloud Native Way, Austin TX', '+1-555-0199'),
              ('ACC1002', 'Alice', 'Smith', 28, 'Female', 'Single', '456 Microservice Lane, New York NY', '+1-555-0144'),
              ('ACC1003', 'Robert', 'Miller', 42, 'Male', 'Divorced', '789 Infrastructure Blvd, Seattle WA', '+1-555-0177');

              -- 2. Insert Matching Account Mappings
              INSERT INTO account_details (
                  account_number, account_balance, account_open_date, debit_card_number, debit_card_expiry_date
              ) VALUES
              ('ACC1001', 5420.50, '2025-01-15', '4321-5678-9012-3456', '2030-12-31'),
              ('ACC1002', 120500.00, '2024-06-20', '5105-1234-5678-9988', '2029-08-31'),
              ('ACC1003', 0.00, '2026-03-01', NULL, NULL);
              SQL_EOF

              mysql < /tmp/setup.sql
              EOF

  tags = { Name = "flipflop-database-server" }
}

output "database_private_ip" {
  value = aws_instance.db_server.private_ip
}