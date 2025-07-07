# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# Vulnerabilidad: Rol IAM con una política de confianza excesivamente permisiva para acceso externo
resource "aws_iam_role" "insecure_cross_account_role" {
  name = "tfm-insecure-cross-account-role-16"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # ¡Vulnerabilidad! Permite que cualquier cuenta de AWS (incluso la de un atacante) asuma este rol.
          # En un escenario real, 'AWS' debería ser un ARN de cuenta específico.
          AWS = "*" # Demasiado permisivo, no debe usarse en producción.
        }
        # La ausencia de 'Condition' con 'sts:ExternalId' hace que sea vulnerable a "confused deputy" si no se controla el rol.
      },
    ]
  })

  tags = {
    Name = "TFM-Insecure-Cross-Account-Role"
  }
}

# Vulnerabilidad: Adjuntar una política de permisos excesivos al rol
resource "aws_iam_role_policy_attachment" "role_policy_attachment_16" {
  role       = aws_iam_role.insecure_cross_account_role.name
  # ¡Vulnerabilidad! Otorga permisos de administrador a este rol accesible externamente.
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Opcional: Un bucket S3 que este rol podría acceder
resource "aws_s3_bucket" "sensitive_data_bucket_16" {
  bucket = "tfm-sensitive-data-16-${random_id.bucket_suffix.hex}"
  acl    = "private"
  tags = {
    Name = "TFM Sensitive Data"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Opcional: Una política de bucket que permitiría acceso si el rol asumido fuera el atacante
# resource "aws_s3_bucket_policy" "bucket_policy" {
#   bucket = aws_s3_bucket.sensitive_data_bucket_16.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           AWS = aws_iam_role.insecure_cross_account_role.arn
#         },
#         Action = [
#           "s3:GetObject"
#         ],
#         Resource = [
#           "${aws_s3_bucket.sensitive_data_bucket_16.arn}/*"
#         ]
#       }
#     ]
#   })
# }