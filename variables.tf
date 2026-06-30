variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "ami_id" {
  type    = string
  default = "ami-03f4878755434977f" # Amazon Linux 2023 for ap-south-1
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "my_home_ip" {
  type        = string
  description = "Your home public IP address (without the /32)"
}

variable "key_name" {
  type        = string
  description = "The name of your existing AWS EC2 Key Pair to allow SSH access"
}
