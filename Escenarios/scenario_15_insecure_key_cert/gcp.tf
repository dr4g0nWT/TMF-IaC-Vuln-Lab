# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-15-gcp"
  project = "your-gcp-project-id"
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-15-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1"
}

# --- Parte 1: Instancia de Compute Engine con disco de arranque no encriptado ---
resource "google_compute_instance" "unencrypted_boot_disk_instance" {
  name         = "tfm-unencrypted-disk-vm-15-gcp"
  machine_type = "e2-micro"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      # No se especifica 'kms_key_self_link' ni 'disk_encryption_key_raw',
      # lo que indica que el disco no está encriptado con CMK.
      # Por defecto, GCP encripta con claves gestionadas por Google (CMEK).
      # La vulnerabilidad se centra en la ausencia de CMK o en la no aplicación forzada.
    }
    # No hay configuración para forzar el cifrado con una clave gestionada por el cliente.
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      # Asigna una IP pública para que la VM sea accesible desde Internet
    }
  }
  tags = {
    Name = "TFM-Unencrypted-Boot-Disk-Instance"
  }
}

# --- Parte 2: Balanceador de carga HTTP (no HTTPS) ---
# Se necesita un grupo de instancias para un balanceador de carga HTTP(S)
resource "google_compute_instance_group" "instance_group" {
  name        = "tfm-instance-group-15"
  zone        = "europe-west1-b"
  network     = google_compute_network.vpc_network.id
  instances   = [google_compute_instance.unencrypted_boot_disk_instance.self_link] # Apunta a la VM insegura
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_backend_service" "backend_service" {
  name        = "tfm-backend-service-15"
  protocol    = "HTTP" # ¡Vulnerabilidad! Backend usa HTTP, no HTTPS
  port_name   = "http"
  timeout_sec = 10
  health_checks = [google_compute_health_check.http_health_check.self_link]

  backend {
    group = google_compute_instance_group.instance_group.self_link
  }
}

resource "google_compute_health_check" "http_health_check" {
  name                = "tfm-http-health-check-15"
  timeout_sec         = 1
  check_interval_sec  = 1
  request_path        = "/"
  port                = 80
  protocol            = "HTTP"
}

resource "google_compute_url_map" "url_map" {
  name            = "tfm-url-map-15"
  default_service = google_compute_backend_service.backend_service.self_link
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "tfm-http-proxy-15"
  url_map = google_compute_url_map.url_map.self_link
  # No se especifica 'ssl_certificates', lo que indica que es un proxy HTTP.
  # Si fuera HTTPS, se usaría 'google_compute_target_https_proxy' con certificados.
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "tfm-http-forwarding-rule-15"
  target     = google_compute_target_http_proxy.http_proxy.self_link
  port_range = "80" # ¡Vulnerabilidad! Escucha en el puerto 80 (HTTP)
  ip_protocol = "TCP"
}