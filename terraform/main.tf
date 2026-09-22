resource "aws_vpc" "shields_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "shields-modernization-vpc"
    Environment = "lab"
    Project     = "linux-modernization"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.shields_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "shields-public-subnet"
    Environment = "lab"
  }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.shields_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "shields-public-subnet-2"
    Environment = "lab"
  }
}
resource "aws_internet_gateway" "shields_igw" {
  vpc_id = aws_vpc.shields_vpc.id

  tags = {
    Name = "shields-internet-gateway"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.shields_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shields_igw.id
  }

  tags = {
    Name = "shields-public-route-table"
  }
}
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_security_group" "legacy_ec2_sg" {
  name        = "shields-legacy-ec2-sg"
  description = "Security group for legacy Linux EC2 instance"
  vpc_id      = aws_vpc.shields_vpc.id

  ingress {
    description     = "Legacy app"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "shields-legacy-ec2-sg"
  }
}
resource "aws_security_group" "alb_sg" {
  name        = "shields-alb-sg"
  description = "Security group for Shields Application Load Balancer"
  vpc_id      = aws_vpc.shields_vpc.id

  ingress {
    description = "Allow HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "shields-alb-sg"
    Environment = "lab"
  }
}
resource "aws_instance" "legacy_linux" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.legacy_ec2_sg.id]
  associate_public_ip_address = true

  lifecycle {
    ignore_changes = [
      associate_public_ip_address
    ]
  }

  tags = {
    Name        = "shields-legacy-linux"
    Environment = "lab"
  }
}
resource "aws_lb_target_group" "legacy_tg" {
  name     = "shields-legacy-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.shields_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name        = "shields-legacy-tg"
    Environment = "lab"
  }
}
resource "aws_lb" "shields_alb" {
  name               = "shields-modernization-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]

  tags = {
    Name        = "shields-modernization-alb"
    Environment = "lab"
  }
}
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.shields_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.legacy_tg.arn
  }
}
resource "aws_lb_target_group_attachment" "legacy_ec2" {
  target_group_arn = aws_lb_target_group.legacy_tg.arn
  target_id        = aws_instance.legacy_linux.id
  port             = 8080
}
resource "aws_iam_role" "ec2_ssm_role" {
  name = "shields-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "shields-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
resource "aws_iam_role" "automation_lambda_role" {
  name = "shields-automation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.automation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "archive_file" "automation_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/automation_lambda.py"
  output_path = "${path.module}/automation_lambda.zip"
}
resource "aws_lambda_function" "automation_lambda" {
  function_name = "shields-ec2-state-automation"
  role          = aws_iam_role.automation_lambda_role.arn
  handler       = "automation_lambda.lambda_handler"

  runtime = "python3.12"

  filename         = data.archive_file.automation_lambda_zip.output_path
  source_code_hash = data.archive_file.automation_lambda_zip.output_base64sha256

  tags = {
    Name        = "shields-ec2-state-automation"
    Environment = "lab"
  }
}
resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name        = "shields-ec2-state-change"
  description = "Detect state changes for the Shields legacy EC2 instance"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]

    detail = {
      instance-id = [aws_instance.legacy_linux.id]
    }
  })
}
resource "aws_cloudwatch_event_target" "automation_lambda_target" {
  rule      = aws_cloudwatch_event_rule.ec2_state_change.name
  target_id = "ShieldsAutomationWorkflow"
  arn       = aws_sfn_state_machine.shields_automation_workflow.arn
  role_arn  = aws_iam_role.eventbridge_step_functions_role.arn
}
resource "aws_iam_role" "step_functions_role" {
  name = "shields-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "states.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "step_functions_lambda_policy" {
  name = "shields-step-functions-lambda-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "lambda:InvokeFunction"
      ]

      Resource = aws_lambda_function.automation_lambda.arn
    }]
  })
}
resource "aws_sfn_state_machine" "shields_automation_workflow" {
  name     = "shields-automation-workflow"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "Orchestrates the Shields EC2 state-change automation"

    StartAt = "ProcessEC2StateChange"

    States = {
      ProcessEC2StateChange = {
        Type     = "Task"
        Resource = aws_lambda_function.automation_lambda.arn
        End      = true
      }
    }
  })
}
resource "aws_iam_role" "eventbridge_step_functions_role" {
  name = "shields-eventbridge-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "events.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "eventbridge_step_functions_policy" {
  name = "shields-eventbridge-step-functions-policy"
  role = aws_iam_role.eventbridge_step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "states:StartExecution"
      ]

      Resource = aws_sfn_state_machine.shields_automation_workflow.arn
    }]
  })
}