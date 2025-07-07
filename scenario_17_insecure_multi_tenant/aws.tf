# Archivo: aws.tf

provider "aws" {
  region = "eu-west-3" # París, Europa
}

# --- Contexto: VPC y subredes para el clúster EKS ---
resource "aws_vpc" "main_17" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tfm-security-vpc-17-aws"
  }
}

resource "aws_subnet" "public_17_a" {
  vpc_id            = aws_vpc.main_17.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  tags = {
    Name = "tfm-security-public-subnet-17a"
  }
}

resource "aws_subnet" "public_17_b" {
  vpc_id            = aws_vpc.main_17.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"
  tags = {
    Name = "tfm-security-public-subnet-17b"
  }
}

resource "aws_internet_gateway" "gw_17" {
  vpc_id = aws_vpc.main_17.id
}

resource "aws_route_table" "public_rt_17" {
  vpc_id = aws_vpc.main_17.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_17.id
  }
}

resource "aws_route_table_association" "public_rta_a_17" {
  subnet_id      = aws_subnet.public_17_a.id
  route_table_id = aws_route_table.public_rt_17.id
}

resource "aws_route_table_association" "public_rta_b_17" {
  subnet_id      = aws_subnet.public_17_b.id
  route_table_id = aws_route_table.public_rt_17.id
}

# --- Vulnerabilidad: EKS con políticas de red débiles (ej. CNI de Calico sin restricciones) ---
# EKS requiere un rol IAM para el clúster
resource "aws_iam_role" "eks_cluster_role" {
  name = "tfm-eks-cluster-role-17"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}


resource "aws_eks_cluster" "insecure_eks_cluster" {
  name     = "tfm-insecure-eks-cluster-17"
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [aws_subnet.public_17_a.id, aws_subnet.public_17_b.id]
    # No se especifica 'public_access_cidrs', por defecto 0.0.0.0/0 (vulnerable)
    # No se usa 'endpoint_private_access'
  }
  # Habilita el control de políticas de red (Network Policy)
  # Pero la vulnerabilidad es la *ausencia* de políticas restrictivas definidas en Kubernetes,
  # o la configuración de Calico/otro CNI que sea por defecto permisiva.
  # Terraform en sí no define NetworkPolicies de Kubernetes, pero sí habilita la capacidad.
  # La vulnerabilidad está en la capa de Kubernetes si no se aplican políticas.

  # Para simular la vulnerabilidad a nivel de IaC, se podría dejar el endpoint público sin restricciones,
  # o en un caso más avanzado, desplegar un CNI que por defecto no aísle el tráfico entre pods/namespaces.
  # La ausencia de restricciones a nivel de EKS para el endpoint de la API:
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# Creación de un grupo de nodos para el EKS cluster
resource "aws_iam_role" "eks_node_role" {
  name = "tfm-eks-node-role-17"

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

resource "aws_iam_role_policy_attachment" "eks_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "insecure_node_group" {
  cluster_name    = aws_eks_cluster.insecure_eks_cluster.name
  node_group_name = "tfm-insecure-node-group-17"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_17_a.id, aws_subnet.public_17_b.id]
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  # Vulnerabilidad simulada: La ausencia de NetworkPolicy de Kubernetes aplicada.
  # Por defecto, en Kubernetes (y por lo tanto EKS), si no hay NetworkPolicy, todo el tráfico
  # entre pods y a la red externa está permitido. Esto rompe el aislamiento.
  # Para un entorno multi-inquilino, esto es una vulnerabilidad clave.
}