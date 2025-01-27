variable "aws_region" {
  description = "AWS region to deploy the resources"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidrs" {
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidrs" {
  description = "CIDR blocks for private subnets"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "instance_type" {
  description = "Instance type for ECS container instances"
  default     = "t3.micro"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  default     = "simpletime-service"
}

variable "desired_capacity" {
  description = "Desired capacity for ECS Auto Scaling Group"
  default     = 2
}
