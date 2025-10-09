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
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "mainVPC"
  }
}

resource "aws_subnet" "publica" {
  vpc_id            = aws_vpc.mainVPC.id
  cidr_block        = "192.168.11.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "publica"
  }
}

resource "aws_subnet" "privada" {
  vpc_id            = aws_vpc.mainVPC.id
  cidr_block        = "192.168.10.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "privada"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mainVPC.id

  tags = {
    Name = "gw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.publica.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mainVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.mainVPC.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.dhcpServer01_private.id
  }
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.privada.id
  route_table_id = aws_route_table.private.id
}

resource "aws_key_pair" "lab_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "ssh_http" {
  name        = "lab-03-ssh-http"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.mainVPC.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all intra-VPC traffic (self-referential for instances in this SG)
  ingress {
    description = "All traffic from within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true # Allows communication between instances using this SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "dhcpServer01" {
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.lab_key.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_http.id]
  subnet_id                   = aws_subnet.publica.id
  associate_public_ip_address = true
  user_data                   = file("user_data")
  source_dest_check = false

  tags = {
    Name = "dhcpServer01"
  }
}

resource "aws_instance" "dhcpServer02" {
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.lab_key.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_http.id]
  subnet_id                   = aws_subnet.publica.id # Sub-rede primária
  associate_public_ip_address = true
  user_data                   = file("user_data")

  tags = {
    Name = "dhcpServer02"
  }
}

# Interface de rede secundária para dhcpServer02 na sub-rede privada
resource "aws_network_interface" "dhcpServer02_private" {
  subnet_id       = aws_subnet.privada.id
  private_ips     = ["192.168.10.10"] # IP válido na sub-rede privada
  security_groups = [aws_security_group.ssh_http.id]

  tags = {
    Name = "dhcpServer02_private_eni"
  }
}

resource "aws_network_interface" "dhcpServer01_private" {
  subnet_id       = aws_subnet.privada.id
  private_ips     = ["192.168.10.11"] # IP válido na sub-rede privada
  security_groups = [aws_security_group.ssh_http.id]
  source_dest_check = false

  tags = {
    Name = "dhcpServer01_private_eni"
  }
}

# Anexar a interface de rede secundária à instância dhcpServer02
resource "aws_network_interface_attachment" "dhcpServer02_private_attachment" {
  instance_id          = aws_instance.dhcpServer02.id
  network_interface_id = aws_network_interface.dhcpServer02_private.id
  device_index         = 1 # Índice 0 é a interface primária
}

resource "aws_network_interface_attachment" "dhcpServer01_private_attachment" {
  instance_id          = aws_instance.dhcpServer01.id
  network_interface_id = aws_network_interface.dhcpServer01_private.id
  device_index         = 1 # Índice 0 é a interface primária
}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = ["192.168.10.11", "192.168.10.10"]
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.mainVPC.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}

resource "aws_instance" "client" {
  count                  = 4
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.lab_key.key_name
  vpc_security_group_ids = [aws_security_group.ssh_http.id]
  subnet_id              = aws_subnet.privada.id

  tags = {
    Name = "client-${count.index + 1}"
  }
}
