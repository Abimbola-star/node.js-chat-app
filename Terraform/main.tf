provider "aws" {
  region = var.aws_region
}

# Create VPC
resource "aws_vpc" "nodejs_app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "nodejs_chat_vpc"
  }
}

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.nodejs_app_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "node.js-app-public-subnet"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nodejs_app_vpc.id
  tags = {
    Name = "node.js-app-igw"
  }
}

# Create Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.nodejs_app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "node.js-app-public-rt"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create Security Group for Chat App
resource "aws_security_group" "nodejs_app_sg" {
  name        = "nodejs-app-sg"
  description = "Security group for chat application"
  vpc_id      = aws_vpc.nodejs_app_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "node.js-app-sg"
  }
}

# Create Security Group for Ansible master
resource "aws_security_group" "ansible_master_sg" {
  name        = "ansible-master-sg"
  description = "Security group for Ansible master"
  vpc_id      = aws_vpc.nodejs_app_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

# Jenkins access
ingress {
    from_port   =  8080
    to_port     =  8080
    protocol    =  "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ansible-master-sg"
  }
}



# Create Chat App EC2 instance
resource "aws_instance" "nodejs_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.nodejs_app_sg.id]

  tags = {
    Name = "nodejs-app-server"
  }
}

# Create Ansible master EC2 instance
resource "aws_instance" "ansible_master" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ansible_master_sg.id]

  tags = {
    Name = "ansible-master"
  }

  # Install Ansible and required packages
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install ansible2 -y
    yum install -y git python3-pip
    pip3 install boto3
  EOF
}

# Allocate Elastic IP for node js App
resource "aws_eip" "nodejs_app_eip" {
  instance = aws_instance.nodejs_server.id
  domain   = "vpc"
  tags = {
    Name = "nodejs-app-eip"
  }
}

# Allocate Elastic IP for Ansible master
resource "aws_eip" "ansible_master_eip" {
  instance = aws_instance.ansible_master.id
  domain   = "vpc"
  tags = {
    Name = "ansible-master-eip"
  }
}

