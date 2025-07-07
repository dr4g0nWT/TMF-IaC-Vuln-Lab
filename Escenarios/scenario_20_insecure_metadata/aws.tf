# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# --- Contexto: VPC y Subred ---
resource "aws_vpc" "main_20" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-20-aws"
  }
}

resource "aws_subnet" "public_20" {
  vpc_id            = aws_vpc.main_20.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  map_public_ip_on_launch = true # Para acceso SSH/HTTP de prueba
  tags = {
    Name = "tfm-security-public-subnet-20"
  }
}

resource "aws_internet_gateway" "gw_20" {
  vpc_id = aws_vpc.main_20.id
}

resource "aws_route_table" "public_rt_20" {
  vpc_id = aws_vpc.main_20.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_20.id
  }
}

resource "aws_route_table_association" "public_rta_20" {
  subnet_id      = aws_subnet.public_20.id
  route_table_id = aws_route_table.public_rt_20.id
}

resource "aws_security_group" "instance_sg_20" {
  name        = "tfm-instance-sg-20-aws"
  description = "Allow HTTP/SSH for testing metadata access"
  vpc_id      = aws_vpc.main_20.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Para acceder a la VM y probar el IMDS
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
}

# IAM Role para la instancia EC2
resource "aws_iam_role" "ec2_instance_profile_role" {
  name = "tfm-ec2-profile-role-20"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "s3_read_policy" {
  name        = "tfm-s3-read-policy-20"
  description = "Allows EC2 instance to read from a specific S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = "s3:GetObject",
        Resource = "arn:aws:s3:::tfm-sensitive-bucket-20-${random_id.bucket_suffix.hex}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read_attachment" {
  role       = aws_iam_role.ec2_instance_profile_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "tfm-ec2-instance-profile-20"
  role = aws_iam_role.ec2_instance_profile_role.name
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "sensitive_data_bucket_20" {
  bucket = "tfm-sensitive-bucket-20-${random_id.bucket_suffix.hex}"
  acl    = "private"
  tags = {
    Name = "TFM Sensitive Data for Instance"
  }
}

# AMI para Ubuntu 20.04 LTS en eu-west-3
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# --- Vulnerabilidad: Instancia EC2 sin IMDSv2 forzado ---
resource "aws_instance" "insecure_ec2_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_20.id
  security_groups             = [aws_security_group.instance_sg_20.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name

  # ¡Vulnerabilidad! No se fuerza IMDSv2. Por defecto, solo IMDSv1 o ambos pueden estar disponibles.
  # La ausencia de 'metadata_options' o 'http_tokens = "required"' es la vulnerabilidad.
  # metadata_options {
  #   http_tokens = "optional" # Permite IMDSv1
  #   http_endpoint = "enabled"
  # }

  # User data con información sensible expuesta vía IMDSv1
  user_data = <<-EOF
              #!/bin/bash
              echo "API_KEY=YOUR_HARDCODED_API_KEY_123" > /etc/app/config.conf
              echo "DATABASE_URL=jdbc:mysql://db.example.com/sensitive_db" >> /etc/app/config.conf
              EOF
  
  tags = {
    Name = "TFM-Insecure-EC2-Instance-Metadata"
  }
}

output "instance_public_ip" {
  value = aws_instance.insecure_ec2_instance.public_ip
  description = "Public IP of the insecure EC2 instance. Try to access metadata at http://169.254.169.254/latest/meta-data/iam/security-credentials/"
}