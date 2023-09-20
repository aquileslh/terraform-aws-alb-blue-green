provider "aws" {
  region = var.AWS_REGION
}

resource "aws_vpc" "devVPC" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "dev_terraform_vpc"
  }
}
# Public Subnet - Provides an VPC subnet resource
resource "aws_subnet" "public_subnet_one" {
  cidr_block              = var.public_cidr_one
  vpc_id                  = aws_vpc.devVPC.id
  map_public_ip_on_launch = true # should be assigned a public IP address
  availability_zone       = var.aws_availability_zones_one
  tags = {
    Name = "dev_terraform_vpc_public_subnet"
  }
}
# Public Subnet - Provides an VPC subnet resource
resource "aws_subnet" "public_subnet_two" {
  cidr_block              = var.public_cidr_two
  vpc_id                  = aws_vpc.devVPC.id
  map_public_ip_on_launch = true # should be assigned a public IP address
  availability_zone       = var.aws_availability_zones_two
  tags = {
    Name = "dev_terraform_vpc_public_subnet"
  }
}
# Private Subnet - Provides an VPC subnet resource
resource "aws_subnet" "private_subnet" {
  cidr_block              = var.private_cidr
  vpc_id                  = aws_vpc.devVPC.id
  map_public_ip_on_launch = false # should be assigned a public IP address
  availability_zone       = var.aws_availability_zones_three
  tags = {
    Name = "dev_terraform_vpc_private_subnet"
  }
}

# Creating Internet Gateway
# Provides a resource to create a VPC Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devVPC.id
  tags = {
    Name = "dev_terraform_vpc_igw"
  }
}
# Provides a resource to create a VPC routing table
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.devVPC.id
  route {
    cidr_block = "0.0.0.0/0" #associated subnet can reach everywhere
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "dev_terraform_vpc_public_route"
  }
}
# Provides a resource to create an association between a Public Route Table and a Public Subnet
resource "aws_route_table_association" "public_subnet_association_one" {
  route_table_id = aws_route_table.public_route.id
  subnet_id      = aws_subnet.public_subnet_one.id
  depends_on     = [aws_route_table.public_route, aws_subnet.public_subnet_one]
}
# Provides a resource to create an association between a Public Route Table and a Public Subnet
resource "aws_route_table_association" "public_subnet_association_two" {
  route_table_id = aws_route_table.public_route.id
  subnet_id      = aws_subnet.public_subnet_two.id
  depends_on     = [aws_route_table.public_route, aws_subnet.public_subnet_two]
}

resource "aws_security_group" "sg_allow_ssh_http" {
  vpc_id = aws_vpc.devVPC.id
  name   = "dev_terraform_vpc_allow_ssh_http"
  tags = {
    Name = "dev_terraform_sg_allow_ssh_http"
  }
}
resource "aws_security_group_rule" "ssh_ingress_access" {
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_allow_ssh_http.id
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
# Ingress Security Port 80 (Inbound)
# resource "aws_security_group_rule" "http_ingress_access" {
#   from_port         = 80
#   protocol          = "tcp"
#   security_group_id = aws_security_group.sg_allow_ssh_http.id
#   to_port           = 80
#   type              = "ingress"
#   cidr_blocks       = ["0.0.0.0/0"]
# }
# Ingress Security Port 8080 (Inbound)
resource "aws_security_group_rule" "http8080_ingress_access" {
  from_port                = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_allow_ssh_http.id
  to_port                  = 8080
  type                     = "ingress"
  source_security_group_id = aws_security_group.alb_sg.id
}
# Egress Security (Outbound)
resource "aws_security_group_rule" "egress_access" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.sg_allow_ssh_http.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.devVPC.id

  # Define ingress rules to allow traffic on ports 80 and 8080
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere (you may want to restrict this)
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from anywhere (you may want to restrict this)
  }
  # Define egress rules to allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an Application Load Balancer
resource "aws_lb" "my_alb" {
  name                       = "my-alb"
  internal                   = false
  load_balancer_type         = "application" # This line specifies it's an Application Load Balancer
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = [aws_subnet.public_subnet_one.id, aws_subnet.public_subnet_two.id] # Replace with your subnet IDs
  enable_deletion_protection = false
}

# RSA key of size 4096 bits
resource "tls_private_key" "rsa-4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = tls_private_key.rsa-4096.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.rsa-4096.private_key_pem
  filename = var.key_name
}

# Create an EC2 instance
resource "aws_instance" "ec2_instance_one" {
  ami           = "ami-04cb4ca688797756f" # AWS Linux 2 (Free Tier)
  instance_type = "t2.micro"              # Free Tier eligible instance type
  #count         = 1                       # Create two instances
  key_name = aws_key_pair.deployer.key_name
  # UserData script to install Node.js and run a simple HTTP server on port 80
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nodejs
              npm install pm2 -g
              npm install express -g
              npm install cors -g
              cat <<EOL > /home/ec2-user/server.js
              const express = require('express');
              const cors = require('cors')
              const app = express()
              app.use(cors())
              app.get('/', (req, res) => {
                  res.end(`Hello PID: 2222`);
              });
              app.get('/check', (req, res) => {
                  console.log('Health Check Request');
                  res.status(200).end();
              });
              app.listen(8080);
              console.log(`Api Server running on 8080 port, PID: 2222`);
              EOL
              cd /home/ec2-user
              pm2 start server.js
              EOF

  subnet_id              = aws_subnet.public_subnet_one.id
  vpc_security_group_ids = [aws_security_group.sg_allow_ssh_http.id]

  tags = {
    Name = "NodeJS-Server-Instance"
  }
}

resource "aws_lb_target_group" "ec2_target_group_one" {
  name     = "ec2-target-group-one"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.devVPC.id # Use your VPC ID

  health_check {
    path                = "/check" # Modify this path as needed
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Register the EC2 instance with the target group
resource "aws_lb_target_group_attachment" "ec2_attachment" {
  target_group_arn = aws_lb_target_group.ec2_target_group_one.arn
  target_id        = aws_instance.ec2_instance_one.id
}

# Create an ALB listener on port 80
resource "aws_lb_listener" "http_listener_one" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_target_group_one.arn
  }
}

# Create an EC2 instance
resource "aws_instance" "ec2_instance_two" {
  ami           = "ami-04cb4ca688797756f" # AWS Linux 2 (Free Tier)
  instance_type = "t2.micro"              # Free Tier eligible instance type
  #count         = 1                       # Create two instances
  key_name = aws_key_pair.deployer.key_name
  # UserData script to install Node.js and run a simple HTTP server on port 80
  user_data = <<-EOF
              #!/bin/bash
             #!/bin/bash
              yum update -y
              yum install -y nodejs
              npm install pm2 -g
              npm install express -g
              npm install cors -g
              cat <<EOL > /home/ec2-user/server.js
              const express = require('express');
              const cors = require('cors')
              const app = express()
              app.use(cors())
              app.get('/', (req, res) => {
                  res.end(`Hello PID: 8888`);
              });
              app.get('/check', (req, res) => {
                  console.log('Health Check Request');
                  res.status(200).end();
              });
              app.listen(8080);
              console.log(`Api Server running on 8080 port, PID: 8888`);
              EOL
              cd /home/ec2-user
              pm2 start server.js
              EOF

  subnet_id              = aws_subnet.public_subnet_two.id
  vpc_security_group_ids = [aws_security_group.sg_allow_ssh_http.id]

  tags = {
    Name = "NodeJS-Server-Instance"
  }
}


resource "aws_lb_target_group" "ec2_target_group_two" {
  name     = "ec2-target-group-two"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.devVPC.id # Use your VPC ID

  health_check {
    path                = "/check" # Modify this path as needed
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
resource "aws_lb_target_group_attachment" "ec2_attachment_two" {
  target_group_arn = aws_lb_target_group.ec2_target_group_two.arn
  target_id        = aws_instance.ec2_instance_two.id
}

# Create an ALB listener on port 80
resource "aws_lb_listener" "http_listener_two" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_target_group_two.arn
  }
}