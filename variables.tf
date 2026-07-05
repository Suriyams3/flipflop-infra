variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "ami_id" {
  type        = string
  description = "Shared AMI ID used for Jump, Gateway, DB, and Apps"
  default     = "ami-0d351f1b760a30161"
}

variable "key_name" {
  type        = string
  description = "The keypair name used to SSH into instances"
  default = "ApsKeyPair"
}

variable "my_home_ip" {
  type        = string
  description = "Your local laptop public IP address (without /32)"
}