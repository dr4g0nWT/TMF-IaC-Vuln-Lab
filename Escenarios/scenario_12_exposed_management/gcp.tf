# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-12-gcp"
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_firewall" "exposed_management_firewall" {
  name    = "tfm-exposed-management-firewall-12"
  network = google_compute_network.vpc_network.name
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!

  # Vulnerabilidad 1: SSH (tcp:22) abierto a 0.0.0.0/0
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # ¡Vulnerabilidad! Acceso SSH público
  description   = "Allow public SSH access"

  # Vulnerabilidad 2: RDP (tcp:3389) también abierto a 0.0.0.0/0 (agrega otra regla)
  # Se puede añadir otra regla o combinar puertos en una sola 'allow' block
  # Para claridad, otra regla para RDP
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = ["0.0.0.0/0"] # ¡Vulnerabilidad! Acceso RDP público
  description   = "Allow public RDP access"

  # Vulnerabilidad 3: Puerto de administración (ej. Jenkins 8080) abierto a 0.0.0.0/0
  allow {
    protocol = "tcp"
    ports    = ["8080"] # Puerto común para Jenkins, Tomcat, etc.
  }
  source_ranges = ["0.0.0.0/0"] # ¡Vulnerabilidad! Acceso de servicio de gestión público
  description   = "Allow public Jenkins/WebApp Management access"
}


resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-12-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1" # Asegúrate de que coincida con la región del provider

  depends_on = [google_compute_network.vpc_network]
}

resource "google_compute_instance" "exposed_instance" {
  name         = "exposed-gcp-vm-12"
  machine_type = "e2-micro"
  zone         = "europe-west1-b" # Ajusta la zona según la región

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      # Asigna una IP pública para que la VM sea accesible desde Internet
    }
  }

  # Asegura que la instancia tenga las etiquetas para que la regla de firewall le aplique
  # Si no hay 'target_tags' en la regla de firewall, aplicará a todas las VMs en la VPC.
  # tags = ["exposed-server"] # Si el firewall tuviera target_tags
}