# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# --- Parte 1: Instancia EC2 con disco raíz no encriptado (si es posible forzarlo) ---
# Nota: AWS encripta los volúmenes de EBS por defecto en cuentas nuevas.
# Para simular la vulnerabilidad, se desactiva explícitamente la encriptación si se permite.
# En algunos casos, puede que no sea posible deshabilitar si la cuenta tiene encriptación por defecto forzada.

resource "aws_vpc" "main_15" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-15-aws"
  }
}

resource "aws_subnet" "public_15" {
  vpc_id     = aws_vpc.main_15.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a"
  tags = {
    Name = "tfm-security-public-subnet-15-aws"
  }
}

resource "aws_internet_gateway" "gw_15" {
  vpc_id = aws_vpc.main_15.id
}

resource "aws_route_table" "public_rt_15" {
  vpc_id = aws_vpc.main_15.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_15.id
  }
}

resource "aws_route_table_association" "public_rta_15" {
  subnet_id      = aws_subnet.public_15.id
  route_table_id = aws_route_table.public_rt_15.id
}

resource "aws_security_group" "web_sg_15" {
  name        = "tfm-web-sg-15-aws"
  description = "Allow HTTP/SSH"
  vpc_id      = aws_vpc.main_15.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
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
}


resource "aws_instance" "unencrypted_ebs_instance" {
  ami           = "ami-0ed0d0f23bf3589b9" # Ubuntu Server 20.04 LTS (eu-west-3)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_15.id
  vpc_security_group_ids = [aws_security_group.web_sg_15.id]
  associate_public_ip_address = true

  root_block_device {
    # Vulnerabilidad 1: Disco raíz de EBS sin encriptar
    encrypted = false # ¡Vulnerabilidad! El disco raíz no está encriptado en reposo
    volume_size = 8
  }

  tags = {
    Name = "TFM-Unencrypted-EBS-Instance"
  }
}

# --- Parte 2: Balanceador de carga que acepta tráfico HTTP (no SSL/TLS) ---
resource "aws_lb" "insecure_http_lb" {
  name               = "tfm-insecure-http-lb-15"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg_15.id] # Permite tráfico en el puerto 80
  subnets            = [aws_subnet.public_15.id]

  enable_deletion_protection = false # Para facilitar la limpieza en un lab

  tags = {
    Name = "TFM-Insecure-HTTP-LB"
  }
}

resource "aws_lb_target_group" "insecure_http_tg" {
  name     = "tfm-insecure-http-tg-15"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_15.id
}

resource "aws_lb_listener" "insecure_http_listener" {
  load_balancer_arn = aws_lb.insecure_http_lb.arn
  port              = 80
  protocol          = "HTTP" # ¡Vulnerabilidad! Escucha en HTTP, no HTTPS
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.insecure_http_tg.arn
  }
  # No hay certificado ni redirección a HTTPS
}