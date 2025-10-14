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
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_key_pair" "chave" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_subnet" "subnetPublica" {
  vpc_id            = aws_vpc.mainVPC.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.az
  depends_on = [aws_internet_gateway.igw]
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
  domain = "mainVPC"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnetPublica.id
  depends_on    = [aws_internet_gateway.gw, aws_eip.eip]
}

resource "aws_route_table" "routePublica" {
  vpc_id = aws_vpc.mainVPC.id
  route = {
    cidr_block = var.cidr
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "routePrivada" {
  vpc_id = aws_vpc.mainVPC.id
  route = {
    cidr_block     = var.cidr
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

resource "aws_route_table_association" "associationPublica" {
  subnet_id      = aws_subnet.subnetPublica.id
  route_table_id = aws_route_table.routePublica.id
}

resource "aws_security_group" "SG" {
  name = "Atividade05"
  description = "SSH security group"
  vpc_id = aws_vpc.mainVPC.id
  
  ingress {
    description = "SSH"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = [var.cidr]
  }

  ingress {
    description = "All trafic VPC"
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [var.cidr]
  }
}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name = var.domain
  domain_name_servers = ["ip magico"]
}

resource "aws_instance" "Server" {
  ami = var.AmazonLinuxAmi
  instance_type = var.instance_type
  key_name = aws_key_pair.chave.key_name
  vpc_security_group_ids = [aws_security_group.SG.id]
  subnet_id = aws_subnet.subnetPublica.id
  associate_public_ip_address = true
  user_data = file("server_user_data")
}

resource "aws_instance" "Cliente" {
  count = 4
  ami = var.AmazonLinuxAmi
  instance_type = var.instance_type
  key_name = aws_key_pair.chave.key_name
  vpc_security_group_ids = [aws_security_group.SG.id]
  subnet_id = aws_subnet.subnetPrivada.id
  tags = {
    Name = "Cliente-${count.index+1}"
  }
}

resource "aws_route53_zone" "DNS" {
  name = "caio.ifes.com"
  vpc{
    vpc_id = aws_vpc.mainVPC.id
  }
}

resource "aws_route53_zone" "DNSreserve" {
  name = "10.0"
  vpc{
    vpc_id = aws_vpc.mainVPC.id
  } 
}

locals {
  private_ip = aws_instance.Server.private_ip
  ip_octets = split (".",local.private_ip)
  dois_ultimos = "${element(local.ip_octets,3)}.${element(local.ip_octets,2)}"
  zona_reversa = join(".",slice(local.ip_octets, 0))
}

resource "aws_route53_record" "DNSrecordServer" {
  zone_id = aws_route53_zone.DNS.id
  name = "server.${var.domain}"
  type = "A"
  records = [aws_instance.Server.private_ip]
}

resource "aws_route53_record" "ReverseDNSrecordServer" {
  zone_id = aws_route53_zone.DNS
  name = "dois ultimos octetos"
  type = "PTR"
  records = ["server.${var.domain}."]
}

resource "aws_route53_record" "DNSrecordClientes" {
  count = 4
  zone_id = aws_route53_zone.DNS.id
  name = "cliente${count.index+1}.caio.ifes.com"
  type = "A"
  records = "pqp"
}