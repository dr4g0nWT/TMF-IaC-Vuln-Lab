# Archivo: gcp.tf

resource "google_compute_network" "vpc_network" {
  name = "tfm-security-vpc-02"
  auto_create_subnetworks = true
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_firewall" "open_ports_firewall" {
  name    = "tfm-insecure-open-ports-firewall"
  network = google_compute_network.vpc_network.name
  project = google_compute_network.vpc_network.project

  direction = "INGRESS"
  priority  = 1000 # La prioridad por defecto, asegúrate de que no haya reglas más permisivas

  # Vulnerabilidad 1: Acceso SSH desde cualquier lugar (0.0.0.0/0)
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # TODO: Esto es una vulnerabilidad (cualquier IP)
  
  # Vulnerabilidad 2: Acceso RDP desde cualquier lugar (0.0.0.0/0)
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  # Vulnerabilidad 3: Acceso a un puerto de DB (ej. PostgreSQL) desde cualquier lugar (0.0.0.0/0)
  allow {
    protocol = "tcp"
    ports    = ["5432"] # Puerto por defecto de PostgreSQL
  }

  target_tags = ["allow-insecure-access"] # Puedes aplicar esta regla a instancias con este tag

  description = "Insecure firewall rule allowing public access to common sensitive ports."

  depends_on = [google_compute_network.vpc_network]
}

# Opcional: Crear una instancia de Compute Engine para aplicar la regla de firewall
# resource "google_compute_instance" "test_vm" {
#   name         = "tfm-test-vm-02"
#   machine_type = "e2-micro"
#   zone         = "us-central1-a" # Cambia según tu zona preferida
#   project      = google_compute_network.vpc_network.project
#   tags         = ["allow-insecure-access"] # Aplica el tag para que la regla de firewall le afecte
#
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#     }
#   }
#
#   network_interface {
#     network = google_compute_network.vpc_network.id
#     access_config {
#       # Asigna una IP pública
#     }
#   }
# }