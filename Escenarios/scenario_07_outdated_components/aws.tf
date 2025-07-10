# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_07" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-07-aws"
  }
}

resource "aws_subnet" "public_07" {
  vpc_id     = aws_vpc.main_07.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región
  tags = {
    Name = "tfm-security-public-subnet-07-aws"
  }
}

resource "aws_security_group" "web_07" {
  name        = "tfm-web-sg-07-aws"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.main_07.id

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

resource "aws_instance" "outdated_os_server" {
  # Vulnerabilidad 1: Uso de una AMI antigua/específica que probablemente no esté parcheada
  # Aquí se usa una AMI de Ubuntu 16.04 LTS (Xenial Xerus) que ya no tiene soporte general.
  # Es crucial reemplazar esto con una AMI de una versión realmente antigua para la prueba.
  # La AMI proporcionada es un ejemplo para una región aleatoria, DEBES VALIDARLA para eu-west-3
  # Por ejemplo: ami-0a89d71c480f2d847 (Ubuntu Server 16.04 LTS HVM, SSD Volume Type para eu-west-3)
  ami           = "ami-0a89d71c480f2d847" # ¡Vulnerabilidad! AMI de Ubuntu 16.04 LTS (antigua)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_07.id
  vpc_security_group_ids = [aws_security_group.web_07.id]
  associate_public_ip_address = true

  tags = {
    Name = "TFM-Outdated-OS-Server"
  }

  # Vulnerabilidad 2: No hay configuración de System Manager (SSM) para parches automatizados
  # En un entorno seguro, se debería adjuntar un rol IAM y configurar SSM para automatizar parches.
  # iam_instance_profile = aws_iam_instance_profile.ssm_profile.name # Comentado para la vulnerabilidad
  # No hay user_data para configurar actualizaciones automáticas de paquetes
}

# IAM Role y Profile para SSM (comentado para simular la falta de parches)
# resource "aws_iam_role" "ssm_role" {
#   name = "tfm-ssm-role-07"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action    = "sts:AssumeRole"
#       Effect    = "Allow"
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#     }]
#   })
# }
#
# resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
#   role       = aws_iam_role.ssm_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }
#
# resource "aws_iam_instance_profile" "ssm_profile" {
#   name = "tfm-ssm-instance-profile-07"
#   role = aws_iam_role.ssm_role.name
# }
#
# # Y luego, para System Manager Patch Manager, se configuraría fuera de este archivo Terraform
# # o se usaría un módulo que gestione la aplicación de parches.