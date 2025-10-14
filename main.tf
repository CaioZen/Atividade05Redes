terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
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
  vpc_id            = aws_vpc.mainVPC.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.az
}

resource "aws_subnet" "subnetPrivada" {
  vpc_id            = aws_vpc.mainVPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mainVPC.id
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnetPublica.id
  depends_on    = [aws_internet_gateway.gw]
}

resource "aws_route_table" "routePublica" {
  vpc_id = aws_vpc.mainVPC.id
  route = {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "routePrivada" {
  vpc_id = aws_vpc.mainVPC.id
  route = {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

resource "aws_route_table_association" "associationPublica" {
  subnet_id      = aws_subnet.subnetPublica.id
  route_table_id = aws_route_table.routePublica.id
}
