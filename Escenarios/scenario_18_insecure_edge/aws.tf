# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# --- Contexto: VPC y subredes para la aplicación ---
resource "aws_vpc" "main_18" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-18-aws"
  }
}

resource "aws_subnet" "public_18_a" {
  vpc_id            = aws_vpc.main_18.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  tags = {
    Name = "tfm-security-public-subnet-18a"
  }
}

resource "aws_subnet" "public_18_b" {
  vpc_id            = aws_vpc.main_18.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"
  tags = {
    Name = "tfm-security-public-subnet-18b"
  }
}

resource "aws_internet_gateway" "gw_18" {
  vpc_id = aws_vpc.main_18.id
}

resource "aws_route_table" "public_rt_18" {
  vpc_id = aws_vpc.main_18.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_18.id
  }
}

resource "aws_route_table_association" "public_rta_a_18" {
  subnet_id      = aws_subnet.public_18_a.id
  route_table_id = aws_route_table.public_rt_18.id
}

resource "aws_route_table_association" "public_rta_b_18" {
  subnet_id      = aws_subnet.public_18_b.id
  route_table_id = aws_route_table.public_rt_18.id
}

resource "aws_security_group" "alb_sg_18" {
  name        = "tfm-alb-sg-18-aws"
  description = "Allow HTTP/HTTPS to ALB"
  vpc_id      = aws_vpc.main_18.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
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

# --- Vulnerabilidad 1: ALB expuesto sin WAF ---
resource "aws_lb" "insecure_alb" {
  name               = "tfm-insecure-alb-18"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_18.id]
  subnets            = [aws_subnet.public_18_a.id, aws_subnet.public_18_b.id]

  enable_deletion_protection = false # Para facilitar la limpieza

  tags = {
    Name = "TFM-Insecure-ALB"
  }
}

resource "aws_lb_target_group" "http_tg_18" {
  name     = "tfm-http-tg-18"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_18.id
}

resource "aws_lb_listener" "http_listener_18" {
  load_balancer_arn = aws_lb.insecure_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http_tg_18.arn
  }
}

# La vulnerabilidad es la *ausencia* de un recurso aws_wafv2_web_acl_association
# Si no hay ninguna asociación WAF, el tráfico pasa sin inspección.
# aws_wafv2_web_acl_association {
#   resource_arn = aws_lb.insecure_alb.arn
#   web_acl_arn = "arn:aws:wafv2:eu-west-3:123456789012:regional/webacl/example-web-acl/abcdef12-3456-7890-abcd-ef1234567890"
# }

# --- Vulnerabilidad 2: CloudFront que expone el origen y permite HTTP ---
resource "aws_s3_bucket" "origin_bucket_18" {
  bucket = "tfm-cf-origin-18-${random_id.bucket_suffix.hex}"
  acl    = "public-read" # ¡Vulnerabilidad! Bucket público, el origen no está protegido
  tags = {
    Name = "TFM CloudFront Origin"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket_object" "index_html_18" {
  bucket = aws_s3_bucket.origin_bucket_18.id
  key    = "index.html"
  content_type = "text/html"
  content = "<h1>Hello from the insecure CloudFront origin!</h1>"
  acl    = "public-read"
}

resource "aws_cloudfront_distribution" "insecure_cloudfront_dist" {
  origin {
    domain_name = aws_s3_bucket.origin_bucket_18.bucket_regional_domain_name
    origin_id   = "S3-Origin-18"
    # No se usa un OAI/OAC, lo que significa que el bucket debe ser público, exponiendo el origen
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution with insecure settings"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Origin-18"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all" # ¡Vulnerabilidad! Permite HTTP y HTTPS, no redirige.
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # ¡Vulnerabilidad! No se fuerza el uso de certificados personalizados ni versiones TLS seguras
  }

  tags = {
    Name = "TFM-Insecure-CloudFront"
  }
}

output "alb_dns_name" {
  value = aws_lb.insecure_alb.dns_name
  description = "DNS name of the insecure ALB (no WAF attached)."
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.insecure_cloudfront_dist.domain_name
  description = "Domain name of the insecure CloudFront distribution (allows HTTP, origin publicly exposed)."
}