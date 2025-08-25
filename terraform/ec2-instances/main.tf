# Lookup latest Amazon Linux 2023 AMI in the region
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # For ARM use: al2023-ami-*-arm64
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Generate an SSH key pair locally and register the public key with AWS
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_file" "private_key_pem" {
  filename        = "${path.module}/${var.project_name}.pem"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Security group allowing SSH and HTTP
resource "aws_security_group" "this" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH (22) and HTTP (80)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# Use the default VPC + a default subnet (simple demo)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# User data: install and start Nginx
locals {
  user_data = <<-EOT
    #!/bin/bash
    dnf -y install nginx
    systemctl enable nginx
    systemctl start nginx
  EOT
}

# EC2 instance
resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = {
    Name = "${var.project_name}-instance"
    Project = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Helpful outputs
output "instance_public_ip" {
  description = "Public IP address"
  value       = aws_instance.this.public_ip
}

output "instance_public_dns" {
  description = "Public DNS"
  value       = aws_instance.this.public_dns
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh -i ${local_file.private_key_pem.filename} ec2-user@${aws_instance.this.public_dns}"
}
