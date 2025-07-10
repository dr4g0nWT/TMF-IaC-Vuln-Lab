# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

resource "aws_vpc" "main_06" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-06-aws"
  }
}

resource "aws_subnet" "public_06" {
  vpc_id     = aws_vpc.main_06.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a" # Ajusta la zona según la región
  tags = {
    Name = "tfm-security-public-subnet-06-aws"
  }
}

resource "aws_security_group" "container_sg" {
  name        = "tfm-container-sg-06-aws"
  description = "Security group for insecure container"
  vpc_id      = aws_vpc.main_06.id

  # Vulnerabilidad: Exponer un puerto sensible (ej. MySQL) públicamente
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Acceso público a puerto de DB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Vulnerabilidad: Definición de tarea ECS con privilegios excesivos o root
resource "aws_ecs_task_definition" "insecure_container_task" {
  family                   = "insecure-app-task"
  network_mode             = "awsvpc" # Requiere ECS Fargate o EC2 launch type con network mode awsvpc
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "insecure-web-app",
      image     = "nginx:latest", # Una imagen de ejemplo
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80,
          protocol      = "tcp"
        },
        {
          containerPort = 3306, # Puerto de DB, expuesto aquí
          hostPort      = 3306,
          protocol      = "tcp"
        }
      ],
      # Vulnerabilidad 1: Privileged container (si fuera EC2 launch type)
      # privileged = true # Si se usa tipo de lanzamiento EC2, otorga privilegios de root al contenedor en el host.
                         # No aplicable a Fargate, pero es una configuración a buscar.

      # Vulnerabilidad 2: Correr como root (por defecto, pero explícitamente se puede no bajar privilegios)
      # user = "0" # Omitir la especificación de un usuario no root, o especificar "0" para root
      # No setting 'readonlyRootFilesystem' to true

      # Vulnerabilidad 3: No hay límites de recursos o health checks robustos
      # No hay "ulimits", "logConfiguration", "healthCheck" detallados
    }
  ])

  # Necesario para el network_mode "awsvpc" con Fargate
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "tfm-ecs-task-execution-role-2025"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "tfm-ecs-task-role-2025"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Opcional: Para desplegar la tarea en un servicio ECS
# resource "aws_ecs_cluster" "main" {
#   name = "tfm-insecure-cluster"
# }
# resource "aws_ecs_service" "insecure_service" {
#   name            = "insecure-app-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.insecure_container_task.arn
#   desired_count   = 1
#   launch_type     = "FARGATE"
#
#   network_configuration {
#     subnets          = [aws_subnet.public_06.id]
#     security_groups  = [aws_security_group.container_sg.id]
#     assign_public_ip = true
#   }
# }