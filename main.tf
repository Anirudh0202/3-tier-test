data "aws_availability_zones" "available" {}

##################################
# VPC
##################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "dev-vpc"
  }
}

##################################
# INTERNET GATEWAY
##################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "dev-igw"
  }
}

##################################
# PUBLIC SUBNETS
##################################

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "dev-public-subnet-${count.index + 1}"
  }
}

##################################
# FRONTEND PRIVATE SUBNETS
##################################

resource "aws_subnet" "frontend" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.frontend_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "dev-frontend-subnet-${count.index + 1}"
  }
}

##################################
# BACKEND PRIVATE SUBNETS
##################################

resource "aws_subnet" "backend" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.backend_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "dev-backend-subnet-${count.index + 1}"
  }
}

##################################
# DATABASE PRIVATE SUBNETS
##################################

resource "aws_subnet" "database" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "dev-db-subnet-${count.index + 1}"
  }
}

##################################
# ELASTIC IPS
##################################

resource "aws_eip" "nat" {
  count = 2

  domain = "vpc"
}

##################################
# NAT GATEWAYS
##################################

resource "aws_nat_gateway" "nat" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "dev-nat-${count.index + 1}"
  }
}

##################################
# PUBLIC ROUTE TABLE
##################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

##################################
# PRIVATE ROUTE TABLES
##################################

resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "dev-private-rt-${count.index + 1}"
  }
}

##################################
# FRONTEND ROUTE ASSOCIATIONS
##################################

resource "aws_route_table_association" "frontend_assoc" {
  count = 2

  subnet_id      = aws_subnet.frontend[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

##################################
# BACKEND ROUTE ASSOCIATIONS
##################################

resource "aws_route_table_association" "backend_assoc" {
  count = 2

  subnet_id      = aws_subnet.backend[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

##################################
# DATABASE ROUTE ASSOCIATIONS
##################################

resource "aws_route_table_association" "database_assoc" {
  count = 2

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

##################################
# SECURITY GROUPS
##################################

resource "aws_security_group" "alb_sg" {
  name   = "dev-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##################################
# FRONTEND SECURITY GROUP
##################################

resource "aws_security_group" "frontend_sg" {
  name   = "dev-frontend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##################################
# BACKEND SECURITY GROUP
##################################

resource "aws_security_group" "backend_sg" {
  name   = "dev-backend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##################################
# DATABASE SECURITY GROUP
##################################

resource "aws_security_group" "db_sg" {
  name   = "dev-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
}

##################################
# IAM ROLE
##################################

resource "aws_iam_role" "ec2_role" {
  name = "dev-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

##################################
# SSM POLICY ATTACHMENT
##################################

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

##################################
# INSTANCE PROFILE
##################################

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dev-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

##################################
# AMAZON LINUX AMI
##################################

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}

##################################
# FRONTEND LAUNCH TEMPLATE
##################################

resource "aws_launch_template" "frontend" {
  name_prefix   = "frontend-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = filebase64("userdata/frontend.sh")
}

##################################
# FRONTEND AUTO SCALING GROUP
##################################

resource "aws_autoscaling_group" "frontend" {
  desired_capacity = var.frontend_desired_capacity
  max_size         = 4
  min_size         = 2

  vpc_zone_identifier = aws_subnet.frontend[*].id

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  health_check_type = "EC2"

  tag {
    key                 = "Name"
    value               = "frontend-instance"
    propagate_at_launch = true
  }
}

##################################
# BACKEND LAUNCH TEMPLATE
##################################

resource "aws_launch_template" "backend" {
  name_prefix   = "backend-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = filebase64("userdata/backend.sh")
}

##################################
# BACKEND AUTO SCALING GROUP
##################################

resource "aws_autoscaling_group" "backend" {
  desired_capacity = var.backend_desired_capacity
  max_size         = 4
  min_size         = 2

  vpc_zone_identifier = aws_subnet.backend[*].id

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  health_check_type = "EC2"

  tag {
    key                 = "Name"
    value               = "backend-instance"
    propagate_at_launch = true
  }
}

##################################
# FRONTEND ALB
##################################

resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

##################################
# BACKEND INTERNAL ALB
##################################

resource "aws_lb" "backend_alb" {
  name               = "backend-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_sg.id]
  subnets            = aws_subnet.backend[*].id
}

##################################
# RDS SUBNET GROUP
##################################

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "dev-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id
}

##################################
# RDS MYSQL
##################################

resource "aws_db_instance" "mysql" {
  identifier        = "dev-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  multi_az                = true
  publicly_accessible     = false
  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  storage_encrypted = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name

  tags = {
    Name = "dev-rds"
  }
}

##################################
# CLOUDWATCH LOG GROUP
##################################

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/dev/three-tier"
  retention_in_days = 30
}

