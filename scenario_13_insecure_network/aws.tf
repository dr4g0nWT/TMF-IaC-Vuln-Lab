# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_13" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-13-aws"
  }
}

resource "aws_subnet" "app_subnet_13" {
  vpc_id     = aws_vpc.main_13.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  tags = {
    Name = "tfm-security-app-subnet-13-aws"
  }
}

resource "aws_subnet" "db_subnet_13" {
  vpc_id     = aws_vpc.main_13.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-3a" # Para simplicidad en este ejemplo, en la misma AZ
  tags = {
    Name = "tfm-security-db-subnet-13-aws"
  }
}

# Vulnerabilidad: Network ACL excesivamente permisiva
resource "aws_network_acl" "overly_permissive_nacl" {
  vpc_id = aws_vpc.main_13.id
  subnet_ids = [aws_subnet.app_subnet_13.id, aws_subnet.db_subnet_13.id] # Aplica a ambas subredes

  # Vulnerabilidad 1: Regla de entrada que permite todo el tráfico (todos los puertos/protocolos) desde cualquier origen
  ingress {
    rule_no    = 100
    protocol   = "-1" # ¡Vulnerabilidad! Todos los protocolos
    action     = "allow"
    cidr_block = "0.0.0.0/0" # ¡Vulnerabilidad! Cualquier origen
    from_port  = 0
    to_port    = 0
  }

  # Vulnerabilidad 2: Regla de salida que permite todo el tráfico (todos los puertos/protocolos) a cualquier destino
  egress {
    rule_no    = 100
    protocol   = "-1" # ¡Vulnerabilidad! Todos los protocolos
    action     = "allow"
    cidr_block = "0.0.0.0/0" # ¡Vulnerabilidad! Cualquier destino
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "TFM-Overly-Permissive-NACL-13"
  }
}

# Recursos adicionales para contexto, pero la vulnerabilidad principal está en la NACL
resource "aws_internet_gateway" "gw_13" {
  vpc_id = aws_vpc.main_13.id
}

resource "aws_route_table" "public_rt_13" {
  vpc_id = aws_vpc.main_13.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_13.id
  }
}

resource "aws_route_table_association" "public_rta_app_13" {
  subnet_id      = aws_subnet.app_subnet_13.id
  route_table_id = aws_route_table.public_rt_13.id
}

resource "aws_instance" "app_server_13" {
  ami           = "ami-0ed0d0f23bf3589b9" # Ubuntu Server 20.04 LTS (eu-west-3)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.app_subnet_13.id
  associate_public_ip_address = true
  tags = {
    Name = "TFM-App-Server-13"
  }
  # Un SG permitiría SSH/HTTP, pero la NACL es más amplia y se aplica primero.
  # No se asocia un Security Group para ilustrar que la NACL es la que abre todo.
}