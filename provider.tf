terraform {
  required_version = ">= 1.0.0"
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

# Common IAM Instance Profile used across your servers

# Dynamic lookup block for your region's Default AWS Network
data "aws_vpc" "default_network" {
  default = true
}