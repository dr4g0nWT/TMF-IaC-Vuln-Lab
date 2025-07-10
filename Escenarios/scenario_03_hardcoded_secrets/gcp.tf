# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-03-gcp"
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-03-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1" # Asegúrate de que coincida con la región del provider

  depends_on = [google_compute_network.vpc_network]
}

resource "google_compute_instance" "insecure_vm" {
  name         = "insecure-gcp-vm-03"
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
      # Asigna una IP pública para que sea un escenario más realista
    }
  }

  # Vulnerabilidad 1: Credencial hardcodeada en los metadatos de la instancia
  metadata = {
    application-database-password = "ExtremelySecurePassword!@#" # ¡Vulnerabilidad!
    smtp-server-credentials       = "user:pass@smtp.example.com"  # ¡Vulnerabilidad!
  }

  # Vulnerabilidad 2: Credencial hardcodeada en un script de inicio
  # Visible en los metadatos 'startup-script'
  metadata_startup_script = <<-EOF
                            #!/bin/bash
                            echo "Setting up application environment..."
                            # ¡Vulnerabilidad! Clave de licencia de software
                            LICENSE_KEY="LIC-XYZ-987-ABC-654" 
                            echo "License key loaded: $LICENSE_KEY"
                            EOF
}