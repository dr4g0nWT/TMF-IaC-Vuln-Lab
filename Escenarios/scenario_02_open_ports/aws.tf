# Archivo: aws.tf

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3" # Cambia según tu región preferida

  tags = {
    Name = "tfm-security-public-subnet"
  }
}

resource "aws_security_group" "open_ports_sg" {
  name        = "tfm-insecure-open-ports-sg"
  description = "Security group with commonly insecure open ports"
  vpc_id      = aws_vpc.main.id

  # Vulnerabilidad 1: Acceso SSH desde cualquier lugar (0.0.0.0/0)
  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Esto es una vulnerabilidad
  }

  # Vulnerabilidad 2: Acceso RDP desde cualquier lugar (0.0.0.0/0)
  ingress {
    description = "Allow RDP from anywhere"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Esto es una vulnerabilidad
  }

  # Vulnerabilidad 3: Acceso a un puerto de DB (ej. MySQL) desde cualquier lugar (0.0.0.0/0)
  ingress {
    description = "Allow MySQL from anywhere"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Esto es una vulnerabilidad
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TFM-Insecure-SG"
  }
}

# Opcional: Crear una instancia EC2 para que el Security Group se aplique
# resource "aws_instance" "test_server" {
#   ami           = "ami-0abcdef1234567890" # AMI Linux/Windows, ajusta según tu necesidad y región
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.public.id
#   vpc_security_group_ids = [aws_security_group.open_ports_sg.id]
#   associate_public_ip_address = true
#
#   tags = {
#     Name = "TFM-Test-Server"
#   }
# }