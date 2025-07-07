# Archivo: s3_aws.tf

resource "aws_s3_bucket" "unencrypted_public_bucket" {
  bucket = "my-highly-insecure-public-unencrypted-bucket-tfm-2025" # Nombre único, debe cambiarse si se despliega
  acl    = "public-read" # Vulnerabilidad 1: Acceso público a través de ACL

  tags = {
    Environment = "Dev"
    Project     = "IaC_Security_TFM_AWS"
  }

  # Vulnerabilidad 2: Falta de cifrado en reposo
  # No se define un bloque 'server_side_encryption_configuration',
  # lo que significa que el bucket no tendrá cifrado en reposo por defecto
  # (o se basará en la configuración predeterminada de S3, que no siempre es lo más estricto).
  # En una configuración segura, se especificaría SSE-S3 o SSE-KMS.
}

resource "aws_s3_bucket_public_access_block" "block_public_access_disabled" {
  bucket = aws_s3_bucket.unencrypted_public_bucket.id

  # Vulnerabilidad 1: Deshabilitar todos los bloques de acceso público
  # Esto permite que las ACLs y las políticas de bucket hagan que el bucket sea público.
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}