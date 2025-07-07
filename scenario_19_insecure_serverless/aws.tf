# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# --- Vulnerabilidad 1: Función Lambda con rol de ejecución excesivamente permisivo ---
resource "aws_iam_role" "insecure_lambda_execution_role" {
  name = "tfm-insecure-lambda-role-19"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = {
    Name = "TFM-Insecure-Lambda-Role"
  }
}

# ¡Vulnerabilidad! Adjuntar una política con permisos de administrador o muy amplios.
resource "aws_iam_role_policy_attachment" "lambda_admin_access_attachment" {
  role       = aws_iam_role.insecure_lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # ¡Grave vulnerabilidad!
}

# --- Contexto: Código de la función Lambda (simple placeholder) ---
resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket        = "tfm-lambda-code-19-${random_id.bucket_suffix.hex}"
  acl           = "private"
  force_destroy = true # Para limpieza fácil
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_code_bucket.id
  key    = "lambda_function.zip"
  source = data.archive_file.lambda_zip_file.output_path
  etag   = filemd5(data.archive_file.lambda_zip_file.output_path)
}

data "archive_file" "lambda_zip_file" {
  type        = "zip"
  source_content = "exports.handler = async (event) => { console.log('Received event:', JSON.stringify(event, null, 2)); return { statusCode: 200, body: 'Hello from Lambda!' }; };"
  output_path = "lambda_function.zip"
}

# --- Vulnerabilidad 2: Función Lambda con información sensible en variables de entorno ---
resource "aws_lambda_function" "insecure_lambda_function" {
  function_name = "tfm-insecure-lambda-19"
  runtime       = "nodejs16.x"
  handler       = "index.handler"
  role          = aws_iam_role.insecure_lambda_execution_role.arn
  s3_bucket     = aws_s3_bucket.lambda_code_bucket.id
  s3_key        = aws_s3_bucket_object.lambda_zip.key

  # ¡Vulnerabilidad! Almacenar secretos directamente en variables de entorno.
  environment {
    variables = {
      DATABASE_PASSWORD = "HardcodedSuperSecretPassword123!" # ¡Grave vulnerabilidad!
      API_KEY           = "YourInsecureApiKeyXYZ123"
    }
  }

  tags = {
    Name = "TFM-Insecure-Lambda-Function"
  }
}

# Opcional: Configurar un trigger S3 (simulación de trigger inseguro si el bucket fuera público)
# resource "aws_s3_bucket_notification" "bucket_notification" {
#   bucket = aws_s3_bucket.lambda_code_bucket.id # Usamos el bucket de código para simplicidad
#   lambda_queue {
#     lambda_function_arn = aws_lambda_function.insecure_lambda_function.arn
#     events              = ["s3:ObjectCreated:*"]
#     filter_prefix       = "uploads/"
#   }
#   depends_on = [aws_lambda_permission.allow_s3_to_invoke_lambda]
# }

# resource "aws_lambda_permission" "allow_s3_to_invoke_lambda" {
#   statement_id  = "AllowExecutionFromS3Bucket"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.insecure_lambda_function.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.lambda_code_bucket.arn
# }