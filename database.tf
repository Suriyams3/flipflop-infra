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
  iam_instance_profile = "flipflop-service-role"

  user_data = <<-EOF
              #!/bin/bash
              # Redirect stdout and stderr to standard log location
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

              echo "=== Starting Native MySQL Server Installation ==="
              dnf update -y

              # 1. Install standard community repository and native MySQL Community Server
              dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
              dnf install -y mysql-community-server --nogpgcheck
              dnf install jq aws-cli -y

              # 1a. Fetch the secure password straight into memory
              FETCHED_ROOT_PASS=$(aws secretsmanager get-secret-value --secret-id "flipflop-db-credentials" --region ap-south-1 --query SecretString --output text | jq -r '.db_password')

              sudo mkdir -p /etc/my.cnf.d
              echo -e "[mysqld]\nbind-address = 0.0.0.0" | sudo tee -a /etc/my.cnf

              # 2. Boot engine and ensure it launches on machine startup
              systemctl start mysqld
              systemctl enable mysqld

              echo "=== Extracting Temp Root Password & Adjusting Permissions ==="
              # Fetch the auto-generated temporary root password
              TEMP_ROOT_PASS=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')

              # Setup primary application user parameters
              cat << 'SQL_EOF' > /tmp/setup.sql
              -- ====================================================================
              -- SCHEMA 1: CREDIT CARD MICROSERVICE DATABASE
              -- ====================================================================
              CREATE DATABASE IF NOT EXISTS flipflop_creditcard_db;

              -- Establish isolated database runtime credentials across schemas
              CREATE USER IF NOT EXISTS 'db_user'@'%' IDENTIFIED BY '$FETCHED_ROOT_PASS';
              GRANT ALL PRIVILEGES ON flipflop_creditcard_db.* TO 'db_user'@'%';

              USE flipflop_creditcard_db;

              -- Create table mapping to the JPA CreditCardDetails Entity
              CREATE TABLE IF NOT EXISTS credit_card_details (
                  account_number VARCHAR(255) NOT NULL,
                  credit_card_number VARCHAR(255) NOT NULL UNIQUE,
                  expiry_date DATE NOT NULL,
                  credit_points_available INT NOT NULL,
                  credit_points_expiry_date DATE NULL,
                  cibil_score INT NOT NULL,
                  PRIMARY KEY (account_number)
              );

              -- Seed Mock Data matching entity signatures
              INSERT INTO credit_card_details (
                  account_number, credit_card_number, expiry_date, credit_points_available, credit_points_expiry_date, cibil_score
              ) VALUES
              ('ACC1001', '4111-2222-3333-4444', '2031-05-31', 4500, '2027-12-31', 780),
              ('ACC1002', '5555-6666-7777-8888', '2029-08-15', 12050, '2028-06-30', 815),
              ('ACC1003', '3782-9999-1111-2222', '2030-11-30', 0, NULL, 650);

              -- ====================================================================
              -- SCHEMA 2: ACCOUNT/PROFILE MICROSERVICE DATABASE
              -- ====================================================================
              CREATE DATABASE IF NOT EXISTS flipflop_account_db;
              GRANT ALL PRIVILEGES ON flipflop_account_db.* TO 'db_user'@'%';

              USE flipflop_account_db;

              -- Create Independent Parent Table (ProfileDetails Entity)
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

              -- Create Dependent Child Table (AccountDetails Entity)
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

              -- Seed Profile Records First
              INSERT INTO profile_details (
                  account_number, first_name, last_name, age, sex, marital_status, address, phone_number
              ) VALUES
              ('ACC1001', 'John', 'Doe', 35, 'Male', 'Married', '123 Cloud Native Way, Austin TX', '+1-555-0199'),
              ('ACC1002', 'Alice', 'Smith', 28, 'Female', 'Single', '456 Microservice Lane, New York NY', '+1-555-0144'),
              ('ACC1003', 'Robert', 'Miller', 42, 'Male', 'Divorced', '789 Infrastructure Blvd, Seattle WA', '+1-555-0177');

              -- Seed Matching Account Mappings Second
              INSERT INTO account_details (
                  account_number, account_balance, account_open_date, debit_card_number, debit_card_expiry_date
              ) VALUES
              ('ACC1001', 5420.50, '2025-01-15', '4321-5678-9012-3456', '2030-12-31'),
              ('ACC1002', 120500.00, '2024-06-20', '5105-1234-5678-9988', '2029-08-31'),
              ('ACC1003', 0.00, '2026-03-01', NULL, NULL);

              -- ====================================================================
              -- SCHEMA 3: CREDIT CARD OFFERS DATABASE
              -- ====================================================================
              CREATE DATABASE IF NOT EXISTS flipflop_offers_db;
              GRANT ALL PRIVILEGES ON flipflop_offers_db.* TO 'db_user'@'%';
              FLUSH PRIVILEGES;

              USE flipflop_offers_db;

              -- Create table mapping to the JPA CreditCardOffer Entity
              CREATE TABLE IF NOT EXISTS credit_card_offers (
                  offer_id INT AUTO_INCREMENT,
                  offer_name VARCHAR(255) NOT NULL,
                  sponsor_name VARCHAR(255) NOT NULL,
                  offer_valid_upto DATE NOT NULL,
                  discount_percentage DECIMAL(5, 2) NOT NULL, -- Precision for standard percentages (e.g., 15.50%)
                  offer_description VARCHAR(500) NULL,
                  reward_points_required INT NOT NULL,
                  cibil_score_required INT NOT NULL,
                  PRIMARY KEY (offer_id)
              );

              -- Seed Mock Data (Omitting offer_id lets AUTO_INCREMENT generate them)
              INSERT INTO credit_card_offers (
                  offer_name, sponsor_name, offer_valid_upto, discount_percentage, offer_description, reward_points_required, cibil_score_required
              ) VALUES
              ('Premium Lounge Access', 'Priority Pass', '2026-12-31', 100.00, 'Free international airport lounge entries.', 5000, 750),
              ('Amazon Shopping Bonanza', 'Amazon Pay', '2026-09-30', 10.00, 'Flat 10% discount on electronics purchases.', 1500, 700),
              ('Fuel Surcharge Waiver', 'IndianOil', '2027-03-31', 2.50, 'Fuel savings across partner outlet stations.', 0, 650);
              SQL_EOF

              # 5. Connect and execute scripts securely using temporary instance token
              mysql --connect-expired-password -u root -p"$TEMP_ROOT_PASS" --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '$FETCHED_ROOT_PASS';"

              # 6. Apply final application script tables using updated root auth
              mysql -u root -p"$FETCHED_ROOT_PASS" < /tmp/setup.sql

              echo "=== MySQL Database Setup Complete ==="
              EOF

  tags = { Name = "flipflop-database-server" }
}

output "database_private_ip" {
  value = aws_instance.db_server.private_ip
}