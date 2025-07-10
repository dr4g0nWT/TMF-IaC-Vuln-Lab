# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# Crear un rol IAM para la función Lambda con permisos excesivos
resource "aws_iam_role" "lambda_exec_role_14" {
  name = "tfm-lambda-exec-role-14"

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
}

# Vulnerabilidad 1: Adjuntar una política de permisos excesivos al rol de Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_14" {
  role       = aws_iam_role.lambda_exec_role_14.name
  # ¡Vulnerabilidad! Política de "Full Access" que no cumple el principio de mínimo privilegio
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # O algo como AmazonS3FullAccess, AmazonEC2FullAccess
  # Para una vulnerabilidad más específica de PaaS, se podría usar algo como DynamoDBFullAccess
}

# Código de ejemplo para la función Lambda (muy básico)
resource "aws_s3_bucket" "lambda_bucket_14" {
  bucket = "tfm-lambda-code-bucket-14-${random_id.bucket_suffix.hex}"
  acl    = "private"
  tags = {
    Name = "TFM Lambda Code Bucket"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_object" "lambda_zip_14" {
  bucket = aws_s3_bucket.lambda_bucket_14.id
  key    = "lambda_function.zip"
  source = data.archive_file.lambda_zip_14.output_path
  etag   = filemd5(data.archive_file.lambda_zip_14.output_path)
}

data "archive_file" "lambda_zip_14" {
  type        = "zip"
  source_content {
    content  = <<-EOF
                exports.handler = async (event) => {
                    const response = {
                        statusCode: 200,
                        body: JSON.stringify('Hello from Lambda!'),
                    };
                    return response;
                };
                EOF
    filename = "index.js"
  }
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "insecure_lambda_14" {
  function_name    = "tfm-insecure-lambda-14"
  s3_bucket        = aws_s3_bucket.lambda_bucket_14.id
  s3_key           = aws_s3_bucket_object.lambda_zip_14.key
  handler          = "index.js"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_exec_role_14.arn
  timeout          = 30
  memory_size      = 128
}

# Vulnerabilidad 2: Permiso de invocación público/no autenticado para la función Lambda
resource "aws_lambda_permission" "allow_public_invocation_14" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.insecure_lambda_14.function_name
  principal     = "apigateway.amazonaws.com" # Se asume que será invocada por APIGateway
  # Para una invocación directamente pública, el principal podría ser "*" o una cuenta AWS específica sin restricciones.
}

# Vulnerabilidad 3: API Gateway sin autenticación, expuesto públicamente
resource "aws_api_gateway_rest_api" "insecure_api_gateway_14" {
  name        = "tfm-insecure-api-14"
  description = "API Gateway expuesto sin autenticación"
}

resource "aws_api_gateway_resource" "api_resource_14" {
  rest_api_id = aws_api_gateway_rest_api.insecure_api_gateway_14.id
  parent_id   = aws_api_gateway_rest_api.insecure_api_gateway_14.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "api_method_14" {
  rest_api_id   = aws_api_gateway_rest_api.insecure_api_gateway_14.id
  resource_id   = aws_api_gateway_resource.api_resource_14.id
  http_method   = "GET"
  authorization = "NONE" # ¡Vulnerabilidad! Sin autenticación/autorización
}

resource "aws_api_gateway_integration" "api_integration_14" {
  rest_api_id             = aws_api_gateway_rest_api.insecure_api_gateway_14.id
  resource_id             = aws_api_gateway_resource.api_resource_14.id
  http_method             = aws_api_gateway_method.api_method_14.http_method
  integration_http_method = "POST" # Lambda espera POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.insecure_lambda_14.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment_14" {
  rest_api_id = aws_api_gateway_rest_api.insecure_api_gateway_14.id
  stage_name  = "v1"

  # Depende del método de integración para forzar una nueva implementación
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api_resource_14.id,
      aws_api_gateway_method.api_method_14.id,
      aws_api_gateway_integration.api_integration_14.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.api_deployment_14.invoke_url}/${aws_api_gateway_resource.api_resource_14.path_part}"
  description = "La URL del API Gateway expuesto. ¡Acceso público sin autenticación!"
}