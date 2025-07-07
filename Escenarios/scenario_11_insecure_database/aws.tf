# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_11" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-11-aws"
  }
}

resource "aws_subnet" "public_11" {
  vpc_id     = aws_vpc.main_11.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región
  tags = {
    Name = "tfm-security-public-subnet-11-aws"
  }
}

resource "aws_db_subnet_group" "db_subnet_group_11" {
  name       = "tfm-db-subnet-group-11"
  subnet_ids = [aws_subnet.public_11.id]
  tags = {
    Name = "TFM-DB-Subnet-Group-11"
  }
}

resource "aws_security_group" "db_sg_public" {
  name        = "tfm-db-sg-public-11"
  description = "Security group for public database access"
  vpc_id      = aws_vpc.main_11.id

  # Vulnerabilidad 1: Acceso público a la base de datos (puerto 3306 abierto a 0.0.0.0/0)
  ingress {
    from_port   = 3306 # Puerto MySQL
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ¡Vulnerabilidad! Acceso público
    description = "Allow public MySQL access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "insecure_rds_db" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t3.micro"
  name                 = "tfm-insecure-db-11"
  username             = "admin"
  password             = "InsecureDBPass123!" # Usa un Secrets Manager en producción
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true

  # Vulnerabilidad 2: Habilitar la accesibilidad pública para la base de datos
  publicly_accessible  = true # ¡Vulnerabilidad! DB accesible públicamente

  vpc_security_group_ids = [aws_security_group.db_sg_public.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group_11.name

  # Vulnerabilidad 3: Falta de configuración de SSL/TLS fuerte o su aplicación
  # No se forza SSL/TLS a través de un grupo de parámetros personalizado
  # Por defecto, RDS permite conexiones no SSL si el cliente no lo requiere.
}

# Un ejemplo de un Parameter Group para forzar SSL (comentado para simular la vulnerabilidad)
# resource "aws_db_parameter_group" "mysql_strict_ssl_pg" {
#   name   = "tfm-mysql-strict-ssl-pg"
#   family = "mysql8.0"
#
#   parameter {
#     name  = "require_ssl"
#     value = "1"
#   }
# }
# Y luego, `parameter_group_name = aws_db_parameter_group.mysql_strict_ssl_pg.name`