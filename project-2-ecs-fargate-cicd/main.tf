resource "aws_ecs_cluster" "a2_cluster" {
  name = "aws-a2-cluster"
}

resource "aws_vpc" "a2_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "aws-a2-vpc"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.a2_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-a2-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.a2_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-a2-public-subnet-2"
  }
}

resource "aws_internet_gateway" "a2_igw" {
  vpc_id = aws_vpc.a2_vpc.id

  tags = {
    Name = "aws-a2-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.a2_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.a2_igw.id
  }

  tags = {
    Name = "aws-a2-public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "ecs_sg" {
  name        = "aws-a2-ecs-sg"
  description = "Security group for ECS service"
  vpc_id      = aws_vpc.a2_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-a2-ecs-sg"
  }
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "aws-a2-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_task_definition" "a2_task" {
  family                   = "aws-a2-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "aws-a2-backend"
      image = "041904914482.dkr.ecr.us-east-2.amazonaws.com/aws-a2-backend:latest"

      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "a2_service" {
  name            = "aws-a2-service"
  cluster         = aws_ecs_cluster.a2_cluster.id
  task_definition = aws_ecs_task_definition.a2_task.arn
  launch_type     = "FARGATE"

  desired_count = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.a2_tg.arn
    container_name   = "aws-a2-backend"
    container_port   = 5000
  }

  depends_on = [
    aws_lb_listener.a2_listener
  ]

  network_configuration {
    subnets = [
      aws_subnet.public_subnet_1.id,
      aws_subnet.public_subnet_2.id
    ]

    security_groups = [
      aws_security_group.ecs_sg.id
    ]

    assign_public_ip = true
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "aws-a2-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.a2_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-a2-alb-sg"
  }
}

resource "aws_lb" "a2_alb" {
  name               = "aws-a2-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb_sg.id
  ]

  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  tags = {
    Name = "aws-a2-alb"
  }
}

resource "aws_lb_target_group" "a2_tg" {
  name        = "aws-a2-target-group"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.a2_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "aws-a2-target-group"
  }
}

resource "aws_lb_listener" "a2_listener" {
  load_balancer_arn = aws_lb.a2_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.a2_tg.arn
  }
}
