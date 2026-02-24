terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region = "eu-west-2"
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "mycomp-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


# Security Group for Public EC2 (Allow SSH + HTTP)
resource "aws_security_group" "public_sg" {
  name   = "public-ec2-sg"
  vpc_id = "vpc-086d2b6ea2881c36a"   # Your VPC ID

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Private EC2
resource "aws_security_group" "private_sg" {
  name   = "private-ec2-sg"
  vpc_id = "vpc-086d2b6ea2881c36a"

  ingress {
    description     = "Allow from Public EC2"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##################################
# 1 EC2 in Public Subnet
##################################

resource "aws_instance" "public_server" {
  ami                    = "ami-018ff7ece22bf96db"
  instance_type          = "t2.micro"
  subnet_id              = "subnet-0068bdcb8bdb2b96e"   # Public subnet
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "Public-EC2"
  }
}

##################################
# 2 EC2 in Private Subnets
##################################

resource "aws_instance" "private_servers" {
  count                  = 2
  ami                    = "ami-018ff7ece22bf96db"
  instance_type          = "t2.micro"
  subnet_id              = element([
    "subnet-03b311564e0b7966f",
    "subnet-04d43f844873d2684"
  ], count.index)

  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "Private-EC2-${count.index + 1}"
  }
}

