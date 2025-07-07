# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_10" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-10-aws"
  }
}

resource "aws_subnet" "public_10" {
  vpc_id     = aws_vpc.main_10.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región
  tags = {
    Name = "tfm-security-public-subnet-10-aws"
  }
}

resource "aws_security_group" "web_10" {
  name        = "tfm-web-sg-10-aws"
  description = "Allow web traffic (HTTP/SSH)"
  vpc_id      = aws_vpc.main_10.id

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

# Variable de entrada para simular la entrada de usuario no validada
variable "user_supplied_input" {
  description = "Simula una entrada de usuario que no se valida y se usa directamente en un script."
  type        = string
  default     = "example_value" # Un valor por defecto para que Terraform planifique sin error
}

resource "aws_instance" "insecure_command_injection_server" {
  ami           = "ami-0ed0d0f23bf3589b9" # Ejemplo para eu-west-3 (Ubuntu Server 20.04 LTS), ajusta si es necesario
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_10.id
  vpc_security_group_ids = [aws_security_group.web_10.id]
  associate_public_ip_address = true

  tags = {
    Name = "TFM-Insecure-Command-Injection-Server"
  }

  # Vulnerabilidad: user_data que ejecuta directamente una variable sin sanitización
  # Un atacante podría inyectar comandos shell en `user_supplied_input`.
  user_data = <<-EOF
              #!/bin/bash
              echo "Processing input: ${var.user_supplied_input}"
              # Aquí, un atacante podría enviar algo como "value; rm -rf /" en user_supplied_input
              # y el script lo ejecutaría.
              echo "${var.user_supplied_input}" > /tmp/output.txt
              service apache2 start # Si se instalara apache
              EOF
  # En un escenario real, 'user_supplied_input' podría venir de una fuente externa
  # o de otro recurso de Terraform que deriva de entradas no confiables.
}