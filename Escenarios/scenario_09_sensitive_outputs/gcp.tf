# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-09-gcp"
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-09-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1" # Asegúrate de que coincida con la región del provider

  depends_on = [google_compute_network.vpc_network]
}

resource "google_compute_instance" "insecure_instance" {
  name         = "insecure-gcp-vm-09"
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
      # Asigna una IP pública
    }
  }

  # Vulnerabilidad: Inyectar una clave SSH vía metadatos y luego exponerla.
  # En un entorno real, usaría IAP o una gestión de claves más segura.
  metadata = {
    ssh-keys = "user:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsrXm...your_public_ssh_key... user@example.com" # CAMBIA ESTO POR UNA CLAVE REAL SI VAS A DESPLEGAR
  }
}

resource "random_password" "api_key" {
  length  = 32
  special = false # Para simplificar la visualización de la vulnerabilidad
  numeric = true
  upper   = true
  lower   = true
}

# Vulnerabilidad: Exponer una clave de API generada en un output
output "api_key_generated_exposed" {
  value       = random_password.api_key.result # ¡Vulnerabilidad! Clave de API expuesta
  description = "Contiene una clave de API generada. ¡Muy sensible!"
  sensitive   = false
}

# Vulnerabilidad: Exponer el contenido del metadata 'ssh-keys' en un output
output "metadata_ssh_keys_exposed" {
  value       = google_compute_instance.insecure_instance.metadata["ssh-keys"] # ¡Vulnerabilidad! Clave SSH de metadatos expuesta
  description = "El contenido del metadata ssh-keys de la instancia. Contiene clave SSH."
  sensitive   = false
}