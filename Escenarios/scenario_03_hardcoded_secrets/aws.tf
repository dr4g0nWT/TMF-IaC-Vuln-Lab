# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-03-aws"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región

  tags = {
    Name = "tfm-security-public-subnet-03-aws"
  }
}

resource "aws_security_group" "web" {
  name        = "tfm-web-sg-03-aws"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.main.id

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

resource "aws_instance" "insecure_app_server" {
  # Asegúrate de usar una AMI válida para la región eu-west-3 (ej: Amazon Linux 2)
  # Puedes buscar AMIs con 'aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query "Images[0].ImageId"'
  ami           = "ami-0ed0d0f23bf3589b9" # Ejemplo para eu-west-3, puede variar
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  associate_public_ip_address = true

  # Vulnerabilidad 1: Credencial hardcodeada en un tag
  tags = {
    Name               = "InsecureWebServer"
    # ¡Vulnerabilidad! Contraseña de una base de datos directamente en un tag
    DatabasePassword   = "MySuperSecretDBPass123!" 
  }

  # Vulnerabilidad 2: Credencial hardcodeada en user_data (script de inicio)
  # Esto sería visible en los detalles de la instancia si se desplegara.
  user_data = <<-EOF
              #!/bin/bash
              echo "Installing web server..."
              # ¡Vulnerabilidad! Clave de API directamente en el script
              export API_KEY="sk_live_very_secret_api_key_456" 
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Insecure server with hardcoded secrets!</h1>" > /var/www/html/index.html
              EOF
}