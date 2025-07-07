# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name                    = "tfm-security-vpc-17-gcp"
  auto_create_subnetworks = false
  project                 = "your-gcp-project-id"
}

resource "google_compute_subnetwork" "gke_subnet" {
  name        = "tfm-security-gke-subnet-17-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1"
  private_ip_google_access = true # Necesario para algunos servicios de GKE
}

# --- Vulnerabilidad: GKE con Network Policy deshabilitada y/o firewall demasiado permisivo ---
resource "google_container_cluster" "insecure_gke_cluster" {
  name     = "tfm-insecure-gke-cluster-17"
  location = "europe-west1"
  project  = "your-gcp-project-id"

  initial_node_count = 1
  min_master_version = "1.27" # Versión de ejemplo, usar una compatible

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform", # ¡Vulnerabilidad! Permisos excesivos para los nodos
    ]
  }

  # Vulnerabilidad 1: Deshabilitar el control de políticas de red (Network Policy)
  # Por defecto, si no se especifica, Network Policy está deshabilitada en GKE.
  # La ausencia de 'network_policy' bloque es la vulnerabilidad.
  # network_policy {
  #   enabled  = false # Si estuviera explícitamente deshabilitado
  #   provider = "CALICO" # O "GKE_NATIVE"
  # }

  # Vulnerabilidad 2: Habilitar el acceso del endpoint público sin restricciones de CIDR
  private_cluster_config {
    enable_private_endpoint = false # Esto hace que el endpoint público sea primario y accesible
    enable_private_nodes = true # Para que las VMs estén en IP privada, pero el endpoint API es público
    master_ipv4_cidr_block = "172.16.0.0/28" # CIDR para el master
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false # No emitir certificados de cliente para el control
    }
  }

  # Creación de rangos secundarios de IP para pods y servicios
  # Esto no es una vulnerabilidad, es parte de la configuración del clúster
  depends_on = [
    google_compute_subnetwork.gke_subnet,
    # Asegúrate de que los rangos secundarios estén definidos en la subred
    # antes de crear el clúster. Esto se haría fuera de este archivo
    # o con un módulo que configure la subred con los rangos secundarios.
  ]

  # La vulnerabilidad también puede venir de reglas de firewall de VPC demasiado permisivas
  # que afectan al tráfico dentro del clúster o entre el clúster y la red externa.
}

# Simular una regla de firewall VPC que permite todo el tráfico interno
# entre pods si Network Policy no está habilitada.
resource "google_compute_firewall" "allow_all_internal_gke_traffic" {
  name        = "tfm-allow-all-internal-gke-17"
  network     = google_compute_network.vpc_network.name
  project     = "your-gcp-project-id"
  direction   = "INGRESS"
  priority    = 65534 # Una prioridad baja para que se aplique si otras no son más específicas.

  # Asumiendo que el rango de IP de los pods está en la VPC.
  # ¡Vulnerabilidad! Permite que los pods se comuniquen con cualquier cosa en la VPC.
  source_ranges = ["10.0.0.0/16"] # Rango de la VPC, incluye la subred de los pods.
  # Si se conocieran los rangos de pods, se especificarían más precisamente.

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  target_tags = ["gke-tfm-insecure-gke-cluster-17-node"] # Tags por defecto de los nodos de GKE
}