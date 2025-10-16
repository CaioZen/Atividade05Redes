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
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_key_pair" "chave" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_subnet" "subnetPublica" {
  vpc_id                  = aws_vpc.mainVPC.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = var.az
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.igw]
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
  depends_on    = [aws_internet_gateway.igw, aws_eip.eip]
}

resource "aws_route_table" "routePublica" {
  vpc_id = aws_vpc.mainVPC.id
  route {
    cidr_block = var.cidr
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "routePrivada" {
  vpc_id = aws_vpc.mainVPC.id
  route {
    cidr_block     = var.cidr
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

resource "aws_route_table_association" "associationPublica" {
  subnet_id      = aws_subnet.subnetPublica.id
  route_table_id = aws_route_table.routePublica.id
}

resource "aws_security_group" "SG" {
  name        = "Atividade05"
  description = "SSH security group"
  vpc_id      = aws_vpc.mainVPC.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
  }

  ingress {
    description = "All trafic VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr]
  }
}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name         = var.domain
  domain_name_servers = ["10.0.0.2"]
}

resource "aws_vpc_dhcp_options_association" "dns_assoc" {
  vpc_id          = aws_vpc.mainVPC.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}

resource "aws_instance" "Server" {
  ami                         = var.AmazonLinuxAmi
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.chave.key_name
  vpc_security_group_ids      = [aws_security_group.SG.id]
  subnet_id                   = aws_subnet.subnetPublica.id
  associate_public_ip_address = true
  #user_data                   = file("server_user_data")
}

resource "aws_instance" "Cliente" {
  count                  = 4
  ami                    = var.AmazonLinuxAmi
  instance_type          = var.instance_type
  key_name               = aws_key_pair.chave.key_name
  vpc_security_group_ids = [aws_security_group.SG.id]
  subnet_id              = aws_subnet.subnetPrivada.id
  tags = {
    Name = "Cliente-${count.index + 1}"
  }
}

resource "aws_route53_zone" "DNS" {
  name = var.domain
  vpc {
    vpc_id = aws_vpc.mainVPC.id
  }
}

resource "aws_route53_zone" "DNSreserve" {
  name = "0.0.10.in-addr.arpa"
  vpc {
    vpc_id = aws_vpc.mainVPC.id
  }
}

resource "aws_route53_zone" "DNSreservePrivate" {
  name = "1.0.10.in-addr.arpa"
  vpc {
    vpc_id = aws_vpc.mainVPC.id
  }
}

resource "aws_route53_record" "DNSrecordServer" {
  zone_id = aws_route53_zone.DNS.id
  name    = "server.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.Server.private_ip]
}

resource "aws_route53_record" "ReverseDNSrecordServer" {
  zone_id = aws_route53_zone.DNSreserve.id
  name    = "${element(split(".", aws_instance.Server.private_ip), 3)}.0.0.10.in-addr.arpa"
  type    = "PTR"
  ttl     = 300
  records = ["server.${var.domain}."]
}

resource "aws_route53_record" "DNSrecordClientes" {
  count   = 4
  zone_id = aws_route53_zone.DNS.id
  name    = "cliente${count.index + 1}.caio.ifes.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.Cliente[count.index].private_ip]
}

resource "aws_route53_record" "ReverseDNSrecordClientes" {
  count   = 4
  zone_id = aws_route53_zone.DNSreservePrivate.id
  name    = "${element(split(".", aws_instance.Cliente[count.index].private_ip), 3)}.1.0.10.in-addr.arpa"
  type    = "PTR"
  ttl     = 300
  records = ["cliente${count.index + 1}.caio.ifes.com."]
}
