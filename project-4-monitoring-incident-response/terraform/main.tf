provider "aws" {
  region = "us-east-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "monitoring_vpc" {
  cidr_block           = "10.40.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "monitoring-lab-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.monitoring_vpc.id
  cidr_block              = "10.40.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring-lab-public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.monitoring_vpc.id

  tags = {
    Name = "monitoring-lab-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.monitoring_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "monitoring-lab-public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-lab-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.monitoring_vpc.id

  ingress {
    description = "SSH from my public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.59.104.142/32"]
  }

  ingress {
    description = "HTTP from the internet"
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
    Name = "monitoring-lab-sg"
  }
}

resource "aws_instance" "monitoring_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = "aws-cloud-key"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "monitoring-lab-server"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "monitoring-alerts"
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm when EC2 CPU exceeds 70 percent"

  dimensions = {
    InstanceId = aws_instance.monitoring_server.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "high-cpu-alarm"
  }
}

resource "aws_cloudwatch_event_rule" "cpu_alarm_event" {
  name        = "cpu-alarm-event-rule"
  description = "Capture CloudWatch alarm state changes"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = ["high-cpu-alarm"]
    }
  })
}
