# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-18-gcp"
  project = "your-gcp-project-id"
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-18-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1"
}

# Backend para el Load Balancer y CDN
resource "google_compute_instance" "backend_vm" {
  name         = "tfm-backend-vm-18-gcp"
  machine_type = "e2-micro"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      # Asigna una IP pública para simular un origen accesible directamente por Cloud CDN
    }
  }

  tags = ["http-server"] # Para la regla de firewall
}

resource "google_compute_firewall" "allow_http_to_backend" {
  name    = "tfm-allow-http-to-backend-18"
  network = google_compute_network.vpc_network.name
  project = "your-gcp-project-id"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"] # Permite HTTP desde cualquier lugar, incluyendo el LB y CDN
  target_tags   = ["http-server"]
}

resource "google_compute_instance_group" "instance_group" {
  name        = "tfm-instance-group-18"
  zone        = "europe-west1-b"
  network     = google_compute_network.vpc_network.id
  instances   = [google_compute_instance.backend_vm.self_link]
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_backend_service" "backend_service" {
  name        = "tfm-backend-service-18"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 10
  health_checks = [google_compute_health_check.http_health_check.self_link]

  backend {
    group = google_compute_instance_group.instance_group.self_link
  }
}

resource "google_compute_health_check" "http_health_check" {
  name                = "tfm-http-health-check-18"
  timeout_sec         = 1
  check_interval_sec  = 1
  request_path        = "/"
  port                = 80
  protocol            = "HTTP"
}

# --- Vulnerabilidad 1: Load Balancer HTTP sin Cloud Armor ---
resource "google_compute_url_map" "url_map" {
  name            = "tfm-url-map-18"
  default_service = google_compute_backend_service.backend_service.self_link
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "tfm-http-proxy-18"
  url_map = google_compute_url_map.url_map.self_link
  # La ausencia de un 'security_policy' asociado al servicio de backend o proxy
  # significa que no hay Cloud Armor.
  # security_policy = google_compute_security_policy.insecure_security_policy.self_link
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "tfm-http-forwarding-rule-18"
  target     = google_compute_target_http_proxy.http_proxy.self_link
  port_range = "80"
  ip_protocol = "TCP"
}

# --- Vulnerabilidad 2: Cloud CDN que permite HTTP y no tiene cache hit rate alto (no relacionado con seguridad) ---
# La vulnerabilidad de CDN es la ausencia de un security policy y permitir HTTP.
# Cloud CDN se habilita en el backend service.
resource "google_compute_backend_service" "cdn_backend_service" {
  name        = "tfm-cdn-backend-service-18"
  protocol    = "HTTP" # ¡Vulnerabilidad! Backend usa HTTP
  port_name   = "http"
  timeout_sec = 10
  health_checks = [google_compute_health_check.http_health_check.self_link]

  backend {
    group = google_compute_instance_group.instance_group.self_link
  }

  cdn_policy {
    enabled = true
    # Por defecto, Cloud CDN cachea HTTP. La vulnerabilidad es la ausencia de redirección/seguridad.
    # No se especifica 'request_coalescing' o 'cache_key_policy' que impacten directamente en seguridad de borde.
    # La ausencia de 'signed_url_keys' si se necesitara contenido privado.
  }
  # No hay security_policy_name aquí para Cloud Armor.
}

resource "google_compute_url_map" "cdn_url_map" {
  name            = "tfm-cdn-url-map-18"
  default_service = google_compute_backend_service.cdn_backend_service.self_link
}

resource "google_compute_target_http_proxy" "cdn_http_proxy" {
  name    = "tfm-cdn-http-proxy-18"
  url_map = google_compute_url_map.cdn_url_map.self_link
  # No hay 'security_policy'
}

resource "google_compute_global_forwarding_rule" "cdn_forwarding_rule" {
  name       = "tfm-cdn-forwarding-rule-18"
  target     = google_compute_target_http_proxy.cdn_http_proxy.self_link
  port_range = "80" # ¡Vulnerabilidad! Escucha en el puerto 80 (HTTP)
  ip_protocol = "TCP"
}

output "lb_ip_address" {
  value = google_compute_global_forwarding_rule.http_forwarding_rule.ip_address
  description = "IP address of the HTTP Load Balancer (no Cloud Armor)."
}

output "cdn_ip_address" {
  value = google_compute_global_forwarding_rule.cdn_forwarding_rule.ip_address
  description = "IP address of the Cloud CDN enabled HTTP Load Balancer (allows HTTP, no Cloud Armor)."
}