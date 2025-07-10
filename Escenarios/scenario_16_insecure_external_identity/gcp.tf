# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

# Creación de un bucket de almacenamiento para aplicar políticas IAM vulnerables
resource "google_storage_bucket" "sensitive_bucket_16" {
  name          = "tfm-sensitive-bucket-16-${random_id.bucket_suffix.hex}" # Nombre de bucket globalmente único
  location      = "EUROPE-WEST1" # Coincidir con la región del provider o ser multiregional
  force_destroy = true # Para facilitar la limpieza del laboratorio
  project       = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!

  uniform_bucket_level_access = true # Recomendado para evitar ACLs a nivel de objeto.
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Vulnerabilidad 1: Permiso IAM a "allUsers" o "allAuthenticatedUsers" en un recurso sensible
resource "google_storage_bucket_iam_member" "public_bucket_access_all_users" {
  bucket = google_storage_bucket.sensitive_bucket_16.name
  role   = "roles/storage.objectViewer" # ¡Vulnerabilidad! Permite a cualquiera ver objetos
  member = "allUsers" # ¡Vulnerabilidad! Acceso público sin autenticación
}

# Simulación 2: Crear una cuenta de servicio para otro "proyecto" (conceptualmente federado)
# y asignarle permisos excesivos en este proyecto.
# En GCP, esto se simula dando a una cuenta de servicio de OTRO proyecto
# un rol en ESTE proyecto. Dado que Terraform opera en un solo proyecto por defecto,
# simularemos una cuenta de servicio con permisos excesivos en este proyecto.

resource "google_service_account" "insecure_service_account" {
  account_id   = "tfm-insecure-sa-16"
  display_name = "TFM Insecure Service Account for Federation Test"
  project      = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

# Vulnerabilidad 2: Asignar a una cuenta de servicio el rol de "Editor" o "Propietario"
# a nivel de proyecto, simula un permiso excesivo para una identidad "externa" o de otro proyecto.
resource "google_project_iam_member" "insecure_sa_project_editor" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  role    = "roles/editor" # ¡Vulnerabilidad! Permisos de editor a nivel de proyecto
  member  = "serviceAccount:${google_service_account.insecure_service_account.email}"
}