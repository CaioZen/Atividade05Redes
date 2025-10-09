terraform {
  required_providers {
    aws ={
        source = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "mainVPC" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnetPublica" {
  vpc_id = aws_vpc.mainVPC.id
  cidr_block = "10.0.0.0/24"
  availability_zone = var.az
}

resource "aws_subnet" "subnetPrivada" {
  vpc_id = aws_vpc.mainVPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.az
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mainVPC.id
}

resource "aws_eip" "name" {
  
}