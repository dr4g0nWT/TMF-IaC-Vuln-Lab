# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-08-gcp"
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-08-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1" # Asegúrate de que coincida con la región del provider

  depends_on = [google_compute_network.vpc_network]
}

resource "google_compute_instance" "single_vm_app" {
  name         = "single-gcp-vm-app-08"
  machine_type = "e2-micro"
  # Vulnerabilidad: Se despliega en una única zona de disponibilidad
  zone         = "europe-west1-b" # ¡Vulnerabilidad! Punto único de fallo

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

  # Vulnerabilidad: No hay Managed Instance Group con múltiples zonas
  # Esto sería la forma robusta de desplegar una aplicación escalable y redundante.
  # También se asume que no hay snapshots automáticos para discos persistentes.
}

resource "google_sql_database_instance" "single_zone_database" {
  project          = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  name             = "tfm-single-zone-db-08"
  database_version = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
    # Vulnerabilidad: No se configura alta disponibilidad (multi_zone)
    # disk_autoresize = true
    # backup_configuration {
    #   enabled            = true
    #   binary_log_enabled = true
    # }
    # ip_configuration {
    #   ipv4_enabled = true
    #   require_ssl  = true
    # }
    # database_flags {
    #   name  = "long_query_time"
    #   value = "0"
    # }
    # disk_size = 20
  }
  # No hay 'master_instance_name' para réplicas de lectura
  # No se especifica 'region' para réplicas de lectura en otra región
  # La ausencia de 'replica_configuration' implica una instancia principal sin HA/DR
}

resource "google_storage_bucket" "regional_storage_bucket" {
  name     = "tfm-regional-storage-bucket-08" # Debe ser globalmente único
  project  = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  location = "EUROPE-WEST1"                  # ¡Vulnerabilidad! Bucket regional, no multi-regional

  # Para un entorno robusto y de DR, se usaría 'MULTI_REGIONAL' o 'DUAL_REGION'
  # storage_class = "STANDARD"
  # versioning {
  #   enabled = true # Buena práctica, pero no cubre redundancia geográfica
  # }
}