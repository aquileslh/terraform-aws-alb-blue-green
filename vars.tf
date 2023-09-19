variable "AWS_REGION" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "key_name" {
  
}

variable "public_cidr_one" {
  default = "10.0.1.0/24"
}
variable "public_cidr_two" {
  default = "10.0.2.0/24"
}
variable "private_cidr" {
  default = "10.0.3.0/24"
}


variable "aws_availability_zones_one" {
  default = "us-east-1a"
}
variable "aws_availability_zones_two" {
  default = "us-east-1b"
}
variable "aws_availability_zones_three" {
  default = "us-east-1c"
}
