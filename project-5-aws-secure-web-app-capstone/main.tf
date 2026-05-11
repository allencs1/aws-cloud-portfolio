terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


resource "aws_security_group" "capstone_sg" {
  name        = "aws-capstone-web-sg"
  description = "Allow SSH from my IP and HTTP from internet"

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.59.104.142/32"]
  }

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-capstone-web-sg"
  }
}

resource "aws_key_pair" "capstone_key" {
  key_name   = "aws-capstone-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEJVZWUdT/O/jJnAEdIwPqoQaRW4zq1Wx5pR2spZJu6r chris@chris-HP-Laptop-15-bs1xx"

}

resource "aws_instance" "capstone_web" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.capstone_key.key_name
  vpc_security_group_ids = [aws_security_group.capstone_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "<h1>AWS Capstone Web Server</h1><p>Using my Linux Terminal, I deployed this with Terraform</p>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "aws-capstone-web-server"
  }
}

resource "aws_instance" "capstone_web_2" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.capstone_key.key_name
  vpc_security_group_ids = [aws_security_group.capstone_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "<h1>AWS Capstone Web Server 2</h1><p>Second EC2 backend behind the ALB.</p>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "aws-capstone-web-server-2"
  }
}



data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


resource "aws_lb" "capstone_alb" {
  name               = "aws-capstone-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.capstone_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "aws-capstone-alb"
  }
}

resource "aws_lb_target_group" "capstone_tg" {
  name     = "aws-capstone-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "capstone_attach" {
  target_group_arn = aws_lb_target_group.capstone_tg.arn
  target_id        = aws_instance.capstone_web.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "capstone_attach_2" {
  target_group_arn = aws_lb_target_group.capstone_tg.arn
  target_id        = aws_instance.capstone_web_2.id
  port             = 80
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.capstone_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.capstone_tg.arn
  }
}


resource "aws_cloudfront_distribution" "capstone_cdn" {
  origin {
    domain_name = aws_lb.capstone_alb.dns_name
    origin_id   = "capstoneEC2Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "capstoneEC2Origin"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "aws-capstone-cloudfront"
  }
}

resource "aws_sns_topic" "capstone_alerts" {
  name = "aws-capstone-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.capstone_alerts.arn
  protocol  = "email"
  endpoint  = "csallen79@icloud.com"
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "aws-capstone-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 10

  alarm_description = "Alarm when EC2 CPU exceeds 70%"

  dimensions = {
    InstanceId = aws_instance.capstone_web.id
  }

  alarm_actions = [aws_sns_topic.capstone_alerts.arn]
}



output "cloudfront_url" {
  value = aws_cloudfront_distribution.capstone_cdn.domain_name
}

output "ec2_public_ip" {
  value = aws_instance.capstone_web.public_ip
}
