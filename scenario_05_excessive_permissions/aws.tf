# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# Vulnerabilidad: Usuario IAM con permisos de administrador (excesivos)
# En un entorno real, los usuarios no deberían tener AdministratorAccess.
# Deberían tener políticas con el mínimo privilegio necesario.
resource "aws_iam_user" "insecure_admin_user" {
  name = "tfm-insecure-admin-user-2025"
  tags = {
    Project     = "IaC_Security_TFM"
    Environment = "Dev"
  }
}

resource "aws_iam_user_policy_attachment" "admin_policy_attachment" {
  user       = aws_iam_user.insecure_admin_user.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # ¡Vulnerabilidad! Acceso excesivo
}

# Vulnerabilidad: Rol IAM para EC2 con permisos amplios (s3:*)
# Una instancia EC2 que solo necesita acceder a un bucket específico
# pero tiene permisos para todos los buckets (s3:*).
resource "aws_iam_role" "insecure_ec2_role" {
  name = "tfm-insecure-ec2-role-2025"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "s3_full_access_policy" {
  name        = "tfm-s3-full-access-policy-2025"
  description = "Allows full S3 access for testing (insecure for general use)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "s3:*" # ¡Vulnerabilidad! Permisos excesivos a todos los recursos S3
        Effect = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_full_access_attachment" {
  role       = aws_iam_role.insecure_ec2_role.name
  policy_arn = aws_iam_policy.s3_full_access_policy.arn
}

# Opcional: Una instancia EC2 que usaría este rol
# resource "aws_vpc" "main_05" {
#   cidr_block = "10.0.0.0/16"
#   tags = {
#     Name = "tfm-security-vpc-05-aws"
#   }
# }
# resource "aws_subnet" "public_05" {
#   vpc_id     = aws_vpc.main_05.id
#   cidr_block = "10.0.1.0/24"
#   map_public_ip_on_launch = true
#   availability_zone = "eu-west-3a"
#   tags = {
#     Name = "tfm-security-public-subnet-05-aws"
#   }
# }
# resource "aws_instance" "test_server_05" {
#   ami           = "ami-0ed0d0f23bf3589b9" # Ejemplo para eu-west-3
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.public_05.id
#   iam_instance_profile = aws_iam_instance_profile.test_profile.name
#   tags = {
#     Name = "TFM-EC2-with-Excessive-S3-Access"
#   }
# }
# resource "aws_iam_instance_profile" "test_profile" {
#   name = "tfm-ec2-test-profile"
#   role = aws_iam_role.insecure_ec2_role.name
# }