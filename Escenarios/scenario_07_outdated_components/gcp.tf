# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_compute_network" "vpc_network" {
  name    = "tfm-security-vpc-07-gcp"
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_compute_subnetwork" "subnet" {
  name        = "tfm-security-subnet-07-gcp"
  ip_cidr_range = "10.0.1.0/24"
  network     = google_compute_network.vpc_network.id
  region      = "europe-west1" # Asegúrate de que coincida con la región del provider

  depends_on = [google_compute_network.vpc_network]
}

resource "google_compute_instance" "outdated_vm" {
  name         = "outdated-gcp-vm-07"
  machine_type = "e2-micro"
  zone         = "europe-west1-b" # Ajusta la zona según la región

  boot_disk {
    initialize_params {
      # Vulnerabilidad 1: Uso de una imagen de SO antigua/específica que no está actualizada.
      # Debian 9 Stretch ya no tiene soporte extendido.
      # Esto debería ser reemplazado por un "family" como "debian-cloud" para versiones actualizadas.
      image = "debian-cloud/debian-9" # ¡Vulnerabilidad! Imagen de Debian 9 (antigua)
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      # Asigna una IP pública para un escenario más completo
    }
  }

  # Vulnerabilidad 2: No se configura el OS Patch Management (OS Config)
  # No se adjunta un Service Account con permisos para OS Config,
  # ni se habilita la API de OS Config, ni se configura una política de parches.
  # metadata = {
  #   enable-osconfig = "true" # Habilita el agente OS Config, pero no configura la política.
  # }
  # No hay user_data para instalar herramientas de parcheo o configurar auto-updates.
}

# Opcional: Service Account para OS Config (comentado para la vulnerabilidad)
# resource "google_service_account" "os_config_sa" {
#   account_id   = "tfm-osconfig-sa-07"
#   display_name = "OS Config Service Account"
#   project      = "your-gcp-project-id"
# }
# resource "google_project_iam_member" "os_config_sa_binding" {
#   project = "your-gcp-project-id"
#   role    = "roles/osconfig.serviceAgent"
#   member  = "serviceAccount:${google_service_account.os_config_sa.email}"
# }
# Y luego, la política de parches se definiría con 'google_os_config_patch_deployment'