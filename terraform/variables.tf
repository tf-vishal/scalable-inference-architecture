variable "aws_region" {
    type = string
    description = "AWS region to deploy resources"
    default = "us-east-1"
}

variable "vpc_cidr" {
    type = string
    description = "CIDR block for the VPC"
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    type = string
    description = "CIDR block for the public subnet"
    default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
    type = string
    description = "CIDR block for the private subnet"
    default = "10.0.2.0/24"
}

variable "project_name" {
    type = string
    description = "Name of the project"
    default = "alchemyst-assignment"
}

variable "worker_instance_type" {
    type = string
    description = "EC2 instance type"
    default = "t2.micro"
}

variable "key_name" {
    type = string
    description = "Name of the EC2 key pair"
    default = "worker-key"
}

variable "ws_port" {
    type = number
    description = "WebSocket port"
    default = 49134
}

variable "http_port" {
    type = number
    description = "HTTP port"
    default = 3111
}

variable "instance_type_inference" {
    type = string
    description = "EC2 instance type for inference"
    default = "t3.large"
}

variable "home_ip" {
    type = string
    description = "Public IP address of the user"
    default = "152.56.163.79/32"
}

variable "bastion_instance_type" {
    type = string
    description = "EC2 instance type for bastion"
    default = "t2.micro"
}