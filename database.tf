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
  instance_type        = "t3.micro"
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
              CREATE DATABASE IF NOT EXISTS flipflop_db;
              CREATE USER IF NOT EXISTS 'db_user'@'%' IDENTIFIED BY 'FlipFlopSecurePass123!';
              GRANT ALL PRIVILEGES ON flipflop_db.* TO 'db_user'@'%';
              FLUSH PRIVILEGES;
              USE flipflop_db;
              CREATE TABLE IF NOT EXISTS users (
                  id INT AUTO_INCREMENT PRIMARY KEY,
                  username VARCHAR(50) NOT NULL,
                  email VARCHAR(100) NOT NULL
              );
              INSERT INTO users (username, email) VALUES ('john_doe', 'john@flipflop.com');
              SQL_EOF

              mysql < /tmp/setup.sql
              EOF

  tags = { Name = "flipflop-database-server" }
}

output "database_private_ip" {
  value = aws_instance.db_server.private_ip
}