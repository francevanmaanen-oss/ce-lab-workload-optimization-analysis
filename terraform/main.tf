terraform {
  required_version = ">= 1.5.0"

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

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  instances = {
    dev-frontend = "Simulates a development frontend server"
    dev-backend  = "Simulates a development backend server"
  }
}

resource "aws_instance" "lab" {
  for_each = local.instances

  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = {
    Name        = each.key
    Description = each.value
    Environment = "development"
    Schedule    = "business-hours"
    Lab         = var.lab_tag
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_ebs_volume" "orphaned" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 1
  type              = "gp3"
  encrypted         = true

  tags = {
    Name      = "orphaned-data-volume"
    Lab       = var.lab_tag
    ManagedBy = "terraform"
  }
}