# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-10-gcp"
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-10-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1" # Asegúrate de que coincida con la región del provider

  depends_on = [google_compute_network.vpc_network]
}

# Variable de entrada para simular la entrada de usuario no validada
variable "unvalidated_hostname_suffix" {
  description = "Sufijo de hostname o parámetro que puede ser vulnerable a inyección en startup-script."
  type        = string
  default     = "myserver" # Valor por defecto
}

resource "google_compute_instance" "insecure_startup_script_vm" {
  name         = "insecure-gcp-vm-${var.unvalidated_hostname_suffix}" # El nombre podría ser parte de la vulnerabilidad
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

  # Vulnerabilidad: metadata_startup_script que ejecuta directamente una variable sin sanitización
  # Un atacante podría inyectar comandos en 'unvalidated_hostname_suffix'.
  metadata_startup_script = <<-EOF
                              #!/bin/bash
                              echo "Setting up server with suffix: ${var.unvalidated_hostname_suffix}"
                              # Comando vulnerable a inyección de comandos:
                              # Si ${var.unvalidated_hostname_suffix} fuera "suffix; cat /etc/passwd", se ejecutaría.
                              echo "Server configuration for ${var.unvalidated_hostname_suffix}" > /var/log/server_setup.log
                              sudo apt-get update -y
                              sudo apt-get install -y nginx
                              sudo systemctl enable nginx
                              sudo systemctl start nginx
                              EOF
}