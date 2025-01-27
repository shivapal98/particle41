terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "ecs-project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
# Create VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "ecs-vpc"
  cidr = var.vpc_cidr

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = var.public_subnets_cidrs
  private_subnets = var.private_subnets_cidrs

  enable_nat_gateway = true
}

# Create ECR Repo
resource "aws_ecr_repository" "ecr" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"
  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep only the last 10 images"
          selection    = {
            tagStatus = "any"
            countType = "imageCountMoreThan"
            countNumber = 10
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }
}

# Fetch ECS-Optimized AMI
data "aws_ami" "ecs_optimized" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "simpletime-cluster"
}

# IAM Role for ECS Instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Launch Template for ECS Instances
resource "aws_launch_template" "ecs_launch_template" {
  name          = "ecs-instance-template"
  instance_type = var.instance_type
  image_id      = data.aws_ami.ecs_optimized.id

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = <<-EOT
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
              EOT

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs-instance"
    }
  }
}

# Auto Scaling Group for ECS Instances
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity     = var.desired_capacity
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = module.vpc.private_subnets
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }

  tags = [
    {
      key                 = "Name"
      value               = "ecs-instance"
      propagate_at_launch = true
    }
  ]
}

# Application Load Balancer
resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "ecs_tg" {
  name     = "ecs-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "simpletime_task" {
  family                   = "simpletime-task"
  network_mode             = "bridge"
  container_definitions = jsonencode([
    {
      name      = "simpletime-container"
      image     = "${aws_ecr_repository.ecr.repository_url}:latest"
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      essential = true
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "simpletime_service" {
  cluster        = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.simpletime_task.arn
  desired_count   = 1

  launch_type = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "simpletime-container"
    container_port   = 3000
  }

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs.id]
  }
}
