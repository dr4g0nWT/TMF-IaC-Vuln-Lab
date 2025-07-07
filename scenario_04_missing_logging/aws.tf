# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_s3_bucket" "unlogged_sensitive_data_bucket" {
  bucket = "tfm-unlogged-sensitive-data-bucket-2025" # Nombre único, cambia si se despliega
  acl    = "private" # El bucket es privado, pero la vulnerabilidad es la falta de logging

  tags = {
    Environment = "Prod"
    Purpose     = "SensitiveData"
  }

  # Vulnerabilidad: Falta de logging de acceso al bucket
  # En una configuración segura, este bucket debería tener configurado el logging de acceso
  # a un bucket de logging dedicado (target_bucket y target_prefix).
  # logging {
  #   target_bucket = aws_s3_bucket.log_bucket.id
  #   target_prefix = "s3_access_logs/"
  # }

  # Otra posible vulnerabilidad no cubierta aquí directamente:
  # Falta de AWS CloudTrail para registrar las llamadas a la API de S3 a nivel de cuenta/organización
  # Sin embargo, esta herramienta se enfoca en la configuración del recurso.
}

# Un bucket de logging para comparar, si se habilitara el logging
# resource "aws_s3_bucket" "log_bucket" {
#   bucket = "tfm-s3-access-logs-destination-2025" # Cambia si se despliega
#   acl    = "log-delivery-write"
#
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid       = "S3ServerAccessLogsPolicy",
#         Effect    = "Allow",
#         Principal = { Service = "logging.s3.amazonaws.com" },
#         Action    = "s3:PutObject",
#         Resource  = "${aws_s3_bucket.log_bucket.arn}/*"
#       }
#     ]
#   })
# }

resource "aws_instance" "server_without_cloudwatch_agent" {
  ami           = "ami-0ed0d0f23bf3589b9" # Ejemplo para eu-west-3 (Ubuntu Server 20.04 LTS), ajusta si es necesario
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id # Asume que hay un subnet definido
  vpc_security_group_ids = [aws_security_group.default.id] # Asume un SG por defecto o crea uno
  associate_public_ip_address = true

  tags = {
    Name = "ServerWithoutCloudWatch"
  }

  # Vulnerabilidad: No se configura el agente de CloudWatch para métricas/logs detallados
  # user_data = <<-EOF
  #             #!/bin/bash
  #             # Comandos para instalar y configurar el agente de CloudWatch
  #             # ...
  #             EOF
}

# Asumiendo que existe un VPC y un Security Group para este ejemplo
resource "aws_vpc" "main_04" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-04-aws"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main_04.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región
  tags = {
    Name = "tfm-security-public-subnet-04-aws"
  }
}

resource "aws_security_group" "default" {
  name        = "tfm-default-sg-04-aws"
  description = "Default security group"
  vpc_id      = aws_vpc.main_04.id

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