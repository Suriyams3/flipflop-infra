variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "ami_id" {
  type    = string
  default = "ami-03f4878755434977f" # Amazon Linux 2023
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_password" {
  type      = string
  sensitive = true
}