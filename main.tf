
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "my_server" {
  ami           = "ami-0cdfc1e40cc5ca08a"
  instance_type = "t3.micro"

  tags = {
    Name = "Terraform-Server"
  }
}
