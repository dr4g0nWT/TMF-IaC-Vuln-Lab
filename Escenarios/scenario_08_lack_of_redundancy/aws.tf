# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_08" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-08-aws"
  }
}

resource "aws_subnet" "single_az_subnet" {
  vpc_id     = aws_vpc.main_08.id
  cidr_block = "10.0.1.0/24"
  # Vulnerabilidad: Todos los recursos se despliegan en una única zona de disponibilidad
  availability_zone = "eu-west-3a" # ¡Vulnerabilidad! Punto único de fallo
  tags = {
    Name = "tfm-security-single-az-subnet-08-aws"
  }
}

resource "aws_security_group" "web_08" {
  name        = "tfm-web-sg-08-aws"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.main_08.id

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

resource "aws_instance" "single_point_of_failure_app" {
  ami           = "ami-0ed0d0f23bf3589b9" # Ejemplo para eu-west-3 (Ubuntu 20.04 LTS), ajusta si es necesario
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.single_az_subnet.id # ¡Vulnerabilidad! Desplegado en un solo AZ
  vpc_security_group_ids = [aws_security_group.web_08.id]
  associate_public_ip_address = true

  tags = {
    Name = "TFM-Single-Point-of-Failure-App"
  }

  # Vulnerabilidad: No hay Auto Scaling Group con distribución Multi-AZ
  # No hay configuración para un balanceador de carga o grupo de Auto Scaling que garantice instancias en múltiples AZs.
  # También se asume que no hay backups de EBS configurados automáticamente para el volumen raíz.
}

resource "aws_db_instance" "single_az_database" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  name                 = "tfm-singledb"
  username             = "admin"
  password             = "MySecureDBPassword123!" # En un entorno real, usar Secrets Manager
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  # Vulnerabilidad: No se habilita Multi-AZ
  multi_az             = false # ¡Vulnerabilidad! Base de datos de un solo AZ
  vpc_security_group_ids = [aws_security_group.web_08.id] # Asume que el SG permite tráfico a la DB
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name # Requiere un DB Subnet Group
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "tfm-db-subnet-group"
  subnet_ids = [aws_subnet.single_az_subnet.id] # ¡Vulnerabilidad! Solo un subnet de un solo AZ
  tags = {
    Name = "TFM-Single-AZ-DB-Subnet-Group"
  }
}