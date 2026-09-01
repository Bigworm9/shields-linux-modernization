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
resource "aws_security_group" "legacy_ec2_sg" {
  name        = "shields-legacy-ec2-sg"
  description = "Security group for legacy Linux EC2 instance"
  vpc_id      = aws_vpc.shields_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  description = "Legacy app"
  from_port   = 8080
  to_port     = 8080
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
    Name = "shields-legacy-ec2-sg"
  }
}
resource "aws_instance" "legacy_linux" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.legacy_ec2_sg.id]

  associate_public_ip_address = true

  tags = {
    Name        = "shields-legacy-linux"
    Environment = "lab"
  }
}