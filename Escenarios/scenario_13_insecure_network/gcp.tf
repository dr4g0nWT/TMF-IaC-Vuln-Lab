# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name                    = "tfm-security-vpc-13-gcp"
  auto_create_subnetworks = false # Deshabilitar auto-creación para control manual
  project                 = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_subnetwork" "app_subnet" {
  name        = "tfm-security-app-subnet-13-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1"

  depends_on = [google_compute_network.vpc_network]
}

resource "google_compute_subnetwork" "db_subnet" {
  name        = "tfm-security-db-subnet-13-gcp"
  ip_cidr_range = "10.0.2.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1"

  depends_on = [google_compute_network.vpc_network]
}

# Vulnerabilidad: Regla de firewall que permite todo el tráfico entre subredes y a/desde Internet
resource "google_compute_firewall" "overly_permissive_internal_egress_firewall" {
  name    = "tfm-overly-permissive-firewall-13"
  network = google_compute_network.vpc_network.name
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!

  # Vulnerabilidad 1: Permite todo el tráfico de salida a cualquier destino (incluyendo Internet)
  direction = "EGRESS"
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
  destination_ranges = ["0.0.0.0/0"] # ¡Vulnerabilidad! Salida a cualquier parte
  description        = "Permite todo el tráfico de salida de todas las VMs a cualquier destino."
  priority           = 1000 # Prioridad predeterminada para reglas de salida.
}

resource "google_compute_firewall" "overly_permissive_internal_ingress_firewall" {
  name    = "tfm-overly-permissive-ingress-firewall-13"
  network = google_compute_network.vpc_network.name
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!

  # Vulnerabilidad 2: Permite todo el tráfico de entrada desde cualquier origen (incluyendo Internet)
  direction = "INGRESS"
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
  source_ranges = ["0.0.0.0/0"] # ¡Vulnerabilidad! Entrada desde cualquier parte
  description   = "Permite todo el tráfico de entrada a todas las VMs desde cualquier origen."
  priority      = 1000 # Prioridad predeterminada para reglas de entrada.
}

# Instancia de ejemplo para ilustrar el efecto (la vulnerabilidad está en las reglas de firewall)
resource "google_compute_instance" "app_instance" {
  name         = "tfm-app-instance-13-gcp"
  machine_type = "e2-micro"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.app_subnet.id
    access_config {
      # Asigna una IP pública para que la VM sea accesible desde Internet
    }
  }
  # No se requiere tags aquí ya que las reglas de firewall aplican a todas las VMs por defecto si no se especifican targets.
}