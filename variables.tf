variable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  default = "dev"
}

variable "vpc_cidr" {
  default = "10.10.0.0/16"
}

variable "public_subnets" {
  type = list(string)

  default = [
    "10.10.1.0/24",
    "10.10.2.0/24"
  ]
}

variable "frontend_subnets" {
  type = list(string)

  default = [
    "10.10.11.0/24",
    "10.10.12.0/24"
  ]
}

variable "backend_subnets" {
  type = list(string)

  default = [
    "10.10.21.0/24",
    "10.10.22.0/24"
  ]
}

variable "database_subnets" {
  type = list(string)

  default = [
    "10.10.31.0/24",
    "10.10.32.0/24"
  ]
}

variable "instance_type" {
  default = "t3.micro"
}

variable "frontend_desired_capacity" {
  default = 2
}

variable "backend_desired_capacity" {
  default = 2
}

variable "db_instance_class" {
  default = "db.t3.micro"
}

variable "db_name" {
  default = "appdb"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  sensitive = true
}

