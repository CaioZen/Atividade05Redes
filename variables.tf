variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "az" {
  description = "Availability zone"
  type = string
  default = "us-east-1c"
}

variable "AmazonLinuxAmi" {
  description = "Amazon Linux AMI"
  type        = string
  default     = "ami-03c4f11b50838ab5d" # example for us-east-1; update as needed
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name to assign to the created AWS key pair"
  type        = string
  default     = "chaveSSH"
}

variable "public_key_path" {
  description = "Path to the public SSH key to upload as Key Pair"
  type        = string
  default     = "C:/Users/Caio/.ssh/id_rsa.pub"
}

variable "cidr" {
  description = "CIDR range allowed to SSH into the instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "domain" {
  description = "variavel de dominio"
  type = string
  default = "caio.ifes.com"
}