# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-04-gcp"
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-04-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1" # Asegúrate de que coincida con la región del provider

  depends_on = [google_compute_network.vpc_network]
}

resource "google_storage_bucket" "unlogged_gcs_bucket" {
  name          = "tfm-unlogged-gcs-bucket-2025" # Debe ser globalmente único
  location      = "EUROPE-WEST1" # Coincide con la región
  project       = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  force_destroy = true 

  # Vulnerabilidad: No se configura el logging de acceso al bucket
  # En GCP, el logging de acceso a buckets se gestiona a través de los logs de auditoría de Cloud Storage
  # y configurando un destino de logging para ellos, no directamente en el bucket.
  # La vulnerabilidad aquí es la ausencia de una configuración explícita para exportar/alertar sobre
  # estos logs de acceso si no se hace a nivel de proyecto/organización.
  # También podría implicar la falta de notificaciones/exportaciones para actividades críticas.

  # Por defecto, GCP genera logs de auditoría. La vulnerabilidad aquí se basa en
  # la falta de un sink explícito para estos logs a un destino de análisis o alarma.
  # Por ejemplo, la ausencia de un 'google_logging_project_sink' o 'google_logging_billing_account_sink'
  # para exportar logs de auditoría de acceso a un Log Bucket o Pub/Sub para su análisis.
  # O la falta de notificaciones para eventos críticos.
}

resource "google_compute_instance" "vm_without_specific_logging" {
  name         = "unlogged-gcp-vm-04"
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
      # Asigna una IP pública para un escenario más completo
    }
  }

  # Vulnerabilidad: No se configura el agente de Logging de Cloud Monitoring/Cloud Logging
  # para logs del sistema operativo o aplicaciones personalizadas.
  # GCP ofrece un agente que recolecta logs del SO y aplicaciones, y la ausencia de su configuración
  # mediante user_data o un script es la vulnerabilidad aquí.
  # metadata_startup_script = <<-EOF
  #                           #!/bin/bash
  #                           # Comandos para instalar y configurar el agente de Cloud Logging
  #                           # curl -sSO https://dl.google.com/cloudagents/add-logging-agent-apt-repo.sh
  #                           # sudo bash add-logging-agent-apt-repo.sh --also-install
  #                           EOF
}

# Un ejemplo de cómo sería un sink para exportar logs de auditoría de un proyecto (comentado)
# resource "google_logging_project_sink" "audit_logs_sink" {
#   name        = "audit-logs-export"
#   destination = "bigquery.googleapis.com/projects/your-gcp-project-id/datasets/audit_logs_dataset" # Cambia esto
#   filter      = "logName:\"cloudaudit.googleapis.com\"" # Exporta todos los logs de auditoría
#   project     = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
# }