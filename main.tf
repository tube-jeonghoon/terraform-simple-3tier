# VPC 설정
resource "aws_vpc" "simple-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "simple-vpc"
  }
}

# IG 설정
resource "aws_internet_gateway" "simple-igw" {
  vpc_id = aws_vpc.simple-vpc.id
  tags = {
    Name = "simple-igw"
  }
}

# Nat Gateway 설정
resource "aws_eip" "simple-nip" {
  vpc = true
  tags = {
    Name = "simple-nip"
  }
}

resource "aws_nat_gateway" "simple-ngw" {
  allocation_id = aws_eip.simple-nip.id
  subnet_id     = aws_subnet.simple-sub-pub-a.id
  tags = {
    Name = "simple-ngw"
  }
}

# Subnet 생성
# public a
resource "aws_subnet" "simple-sub-pub-a" {
  vpc_id            = aws_vpc.simple-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
  # public ip를 할당하기 위해 true로 설정
  map_public_ip_on_launch = true

  tags = {
    Name = "simple-sub-pub-a"
  }

}

# public c
resource "aws_subnet" "simple-sub-pub-c" {
  vpc_id            = aws_vpc.simple-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"
  # public ip를 할당하기 위해 true로 설정
  map_public_ip_on_launch = true

  tags = {
    Name = "simple-sub-pub-c"
  }

}

# Route table
# public > igw
resource "aws_route_table" "simple-rt-pub" {
  vpc_id = aws_vpc.simple-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.simple-igw.id
  }
  tags = {
    Name = "simple-rt-pub"
  }
}

# public subnet을 public route table에 연결
resource "aws_route_table_association" "simple-rtass-pub-a" {
  subnet_id      = aws_subnet.simple-sub-pub-a.id
  route_table_id = aws_route_table.simple-rt-pub.id
}

# WEB & WAS SERVER
# security group
resource "aws_security_group" "simple-sg-pub-a" {
  name        = "simple-sg-pub-a"
  description = "simple-sg-pub-a"
  vpc_id      = aws_vpc.simple-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
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
    Name = "simple-sg-pub-a"
  }
}

# web
resource "aws_instance" "simple-web" {
  ami               = "ami-0fd0765afb77bcca7"
  instance_type     = "t3.small"
  availability_zone = "ap-northeast-2a"

  subnet_id = aws_subnet.simple-sub-pub-a.id
  key_name  = aws_key_pair.mykeypair.key_name
  vpc_security_group_ids = [
    aws_security_group.simple-sg-pub-a.id
  ]
  tags = {
    Name = "simple-web-pub"
  }
}

# db
resource "aws_instance" "simple-db" {
  ami               = "ami-0fd0765afb77bcca7"
  instance_type     = "t3.small"
  availability_zone = "ap-northeast-2a"

  subnet_id = aws_subnet.simple-sub-pub-a.id
  key_name  = aws_key_pair.mykeypair.key_name
  vpc_security_group_ids = [
    aws_security_group.simple-sg-pub-a.id
  ]
  tags = {
    Name = "simple-db"
  }
}

# Application Load Balencer (ALB)
# alb 생성
resource "aws_lb" "simple-alb-web" {
  name               = "simple-alb-web"
  internal           = false # 외부
  load_balancer_type = "application"
  security_groups    = [aws_security_group.simple-sg-alb-web.id]                       # alb는 sg 필요
  subnets            = [aws_subnet.simple-sub-pub-a.id, aws_subnet.simple-sub-pub-c.id] # public subnet에서 web 통신
  tags = {
    Name = "simple-alb-web"
  }
}

# 타겟그룹 생성
resource "aws_lb_target_group" "simple-atg-web" {
  name        = "simple-atg-web"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = aws_vpc.simple-vpc.id
  target_type = "instance"
  tags = {
    Name = "simple-atg-web"
  }
}

# 리스너 생성
resource "aws_lb_listener" "simple-alt-web" {
  load_balancer_arn = aws_lb.simple-alb-web.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.simple-atg-web.arn
  }
}

resource "aws_lb_target_group_attachment" "simple-att-web1" {
  target_group_arn = aws_lb_target_group.simple-atg-web.arn
  target_id        = aws_instance.simple-web.id
  port             = 80
}


resource "aws_security_group" "simple-sg-alb-web" {
  name        = "simple-sg-alb-web"
  description = "simple-sg-alb-web"
  vpc_id      = aws_vpc.simple-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
    Name = "simple-sg-alb-web"
  }
}



