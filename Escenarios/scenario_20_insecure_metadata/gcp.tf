# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-20-gcp"
  project = "your-gcp-project-id"
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-20-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1"
}

resource "google_compute_firewall" "allow_ssh_http" {
  name    = "tfm-allow-ssh-http-20"
  network = google_compute_network.vpc_network.name
  project = "your-gcp-project-id"

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "ssh"]
}

# --- Contexto: Service Account para la instancia ---
resource "google_service_account" "instance_sa" {
  account_id   = "tfm-instance-sa-20"
  display_name = "TFM Instance Service Account"
  project      = "your-gcp-project-id"
}

# Asignar un rol básico a la cuenta de servicio (ej. para leer Secrets, si se quiere simular escalada)
resource "google_project_iam_member" "instance_sa_secret_reader" {
  project = "your-gcp-project-id"
  role    = "roles/secretmanager.secretAccessor" # Un rol que podría ser explotado si se accede a la SA
  member  = "serviceAccount:${google_service_account.instance_sa.email}"
}

# --- Vulnerabilidad: Instancia con metadata que contiene información sensible ---
resource "google_compute_instance" "insecure_gcp_instance" {
  name         = "tfm-insecure-gcp-instance-20"
  machine_type = "e2-micro"
  zone         = "europe-west1-b"
  project      = "your-gcp-project-id"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      # Asigna una IP pública para facilitar el acceso de prueba
    }
  }

  service_account {
    email  = google_service_account.instance_sa.email
    scopes = ["cloud-platform"] # ¡Vulnerabilidad! Alcance excesivo del token de acceso a la API
  }

  # ¡Vulnerabilidad! Almacenar credenciales sensibles directamente en metadata o startup-script.
  # Metadata customizada es accesible desde la instancia (ej. curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/sensitive-key -H "Metadata-Flavor: Google")
  metadata = {
    sensitive-api-key = "GCP_Hardcoded_API_Key_XYZ" # ¡Grave vulnerabilidad!
    database-user     = "prod_user"
  }

  # Startup script que expone o utiliza información sensible
  metadata_startup_script = <<-EOF
                              #!/bin/bash
                              echo "APP_SECRET_TOKEN=AnotherInsecureToken" > /var/log/app_secret.log
                              chmod 644 /var/log/app_secret.log # Permisos permisivos al archivo de log
                              EOF

  tags = ["http-server", "ssh"]
}

output "instance_public_ip" {
  value = google_compute_instance.insecure_gcp_instance.network_interface[0].access_config[0].nat_ip
  description = "Public IP of the insecure GCP instance. Try to access metadata via http://metadata.google.internal/"
}