# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Create TLS Algorithm
resource "tls_private_key" "test1" {
  algorithm = "RSA"
}

# Create Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.test1.public_key_openssh
}

# Create downloadable PEM file
resource "local_sensitive_file" "pem_our_server" {
  content  = tls_private_key.test1.private_key_pem
  filename = "our_server_keypair.pem"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "webserver-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a"]
  public_subnets = ["10.0.1.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_http"
  }
}

resource "aws_instance" "web_server" {
  ami                         = "ami-080e1f13689e07408"
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.allow_http.id]
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              sudo rm -rf /var/www/html/*
              git clone https://gitlab.com/farhaz1449/deploy-webserver.git
              sudo cp -rf deploy-webserver/IndexFile/index.html /var/www/html/
              sudo rm -rf deploy-webserver/
              EOF

  tags = {
    Name = "WebServer"
  }
}


