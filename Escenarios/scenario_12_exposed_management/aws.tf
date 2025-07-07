# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_12" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-12-aws"
  }
}

resource "aws_subnet" "public_12" {
  vpc_id     = aws_vpc.main_12.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región
  tags = {
    Name = "tfm-security-public-subnet-12-aws"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_12.id
  tags = {
    Name = "tfm-igw-12"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main_12.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "tfm-rt-12"
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public_12.id
  route_table_id = aws_route_table.rt.id
}


resource "aws_security_group" "exposed_management_sg" {
  name        = "tfm-exposed-management-sg-12-aws"
  description = "Security group with exposed management ports"
  vpc_id      = aws_vpc.main_12.id

  # Vulnerabilidad 1: SSH (22) abierto a todo el mundo
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ¡Vulnerabilidad! Acceso SSH público
    description = "Allow public SSH access"
  }

  # Vulnerabilidad 2: RDP (3389) abierto a todo el mundo
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ¡Vulnerabilidad! Acceso RDP público
    description = "Allow public RDP access"
  }

  # Vulnerabilidad 3: Puerto de administración de DB (ej. PostgreSQL 5432) abierto a todo el mundo
  ingress {
    from_port   = 5432 # Puerto PostgreSQL
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ¡Vulnerabilidad! Acceso DB Admin público
    description = "Allow public PostgreSQL admin access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "exposed_server" {
  ami           = "ami-0ed0d0f23bf3589b9" # Ejemplo para eu-west-3 (Ubuntu Server 20.04 LTS)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_12.id
  vpc_security_group_ids = [aws_security_group.exposed_management_sg.id] # Asocia el SG vulnerable
  associate_public_ip_address = true

  tags = {
    Name = "TFM-Exposed-Management-Server"
  }
}

# Opcional: Una base de datos RDS que usaría este Security Group (comentado)
# resource "aws_db_instance" "exposed_rds" {
#   allocated_storage    = 20
#   engine               = "postgres"
#   engine_version       = "13.6"
#   instance_class       = "db.t3.micro"
#   name                 = "tfm-exposed-rds-12"
#   username             = "admin"
#   password             = "SecurePassword123!"
#   publicly_accessible  = true # Requiere un IGW y rutas públicas
#   vpc_security_group_ids = [aws_security_group.exposed_management_sg.id]
#   db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name # Necesita un DB Subnet Group
# }