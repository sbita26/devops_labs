variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2" # Sydney (change if needed)
}

variable "project_name" {
  description = "Project tag/name prefix"
  type        = string
  default     = "ec2-demo"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH (set to your IP/32)"
  type        = string
  default     = "58.167.158.246/32" # For demos only. Replace with YOUR_IP/32 for security.
}