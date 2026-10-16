terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "himanktfbucket2"
    key          = "terraform-lab/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}


                                                                                                             # Variables


variable "aws_region" {
  description = "AWS region where infrastructure will be created."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix for this lab infrastructure."
  type        = string
  default     = "terraform-lab"
}

variable "my_ip_cidr" {
  description = "Your public IPv4 CIDR for SSH"
  type        = string
  # default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.my_ip_cidr)) && endswith(var.my_ip_cidr, "/32")
    error_message = "my_ip_cidr must be a single IPv4 address with /32, e.g. 203.0.113.10/32."
  }
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID in the selected region."
  type        = string
  default     = "ami-0cdfc1e40cc5ca08a"
}

variable "allow_http" {
  description = "Allow inbound HTTP from the internet for a public website."
  type        = bool
  default     = true
}


                                                                                                           # Networking: new VPC + public subnet


resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}



                                                                                                        # Security group + explicit rules


resource "aws_security_group" "web" {
  name        = "${var.project_name}-sg"
  description = "SSH access and optional HTTP"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.web.id
  description       = "SSH from my IP"
  cidr_ipv4         = var.my_ip_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  count             = var.allow_http ? 1 : 0
  security_group_id = aws_security_group.web.id
  description       = "Public HTTP for a website"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.web.id
  description       = "Allow outbound IPv4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


                                                                                     # EC2 instance in the new VPC subnet


resource "aws_instance" "my_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "${var.project_name}-server"
  }

  depends_on = [aws_route_table_association.public]
}

                                                                                              # ----------------------------
                                                                                              # Outputs
                                                                                              # ----------------------------

output "vpc_id" {
  description = "ID of the new VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the instance security group."
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.my_server.id
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 instance."
  value       = aws_instance.my_server.public_ip
}

output "ssh_command" {
  description = "SSH command template; configure a key pair separately if you plan to use SSH."
  value       = "ssh ec2-user@${aws_instance.my_server.public_ip}"
}
