# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_09" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-09-aws"
  }
}

resource "aws_subnet" "public_09" {
  vpc_id     = aws_vpc.main_09.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región
  tags = {
    Name = "tfm-security-public-subnet-09-aws"
  }
}

resource "aws_security_group" "web_09" {
  name        = "tfm-web-sg-09-aws"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.main_09.id

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

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tfm-generated-key-09"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_instance" "insecure_server" {
  ami           = "ami-0ed0d0f23bf3589b9" # Ejemplo para eu-west-3 (Ubuntu Server 20.04 LTS), ajusta si es necesario
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_09.id
  vpc_security_group_ids = [aws_security_group.web_09.id]
  associate_public_ip_address = true
  key_name      = aws_key_pair.generated_key.key_name

  tags = {
    Name = "TFM-Server-with-Sensitive-Output"
  }
}

# Vulnerabilidad: Exponer la clave privada SSH en un output
output "ssh_private_key_exposed" {
  value       = tls_private_key.ssh_key.private_key_pem # ¡Vulnerabilidad! Clave privada expuesta
  description = "Contiene la clave privada SSH generada. ¡No debe ser expuesta en entornos de producción!"
  sensitive   = false # Incluso si 'sensitive' es true, algunas herramientas de escaneo lo detectan.
                      # La vulnerabilidad es la presencia en el output.
}

# Vulnerabilidad: Exponer la IP privada del servidor en un output (cuando no debería ser pública)
output "server_private_ip_exposed" {
  value       = aws_instance.insecure_server.private_ip # ¡Vulnerabilidad! IP privada expuesta
  description = "Contiene la IP privada del servidor. Considera si realmente necesita ser un output."
  sensitive   = false
}