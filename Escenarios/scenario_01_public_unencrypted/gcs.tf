# Archivo: gcs.tf

resource "google_project" "project" {
  project_id = "tfm-security-project-2025" # Cambia esto a tu ID de proyecto de GCP
  name       = "TFM Security Project"
}

resource "google_storage_bucket" "unencrypted_public_bucket" {
  name          = "my-highly-insecure-public-unencrypted-gcs-bucket-tfm-2025" # Debe ser globalmente único
  location      = "europe-west1"
  project       = google_project.project.project_id
  force_destroy = true # Para facilitar la eliminación después de las pruebas

  # Vulnerabilidad 1: Acceso público mediante IAM
  # Se otorga el rol de 'roles/storage.objectViewer' al grupo 'allUsers',
  # lo que permite a cualquier persona en Internet leer los objetos del bucket.
  uniform_bucket_level_access = false # Permite que las ACLs de objetos individuales anulen los permisos de bucket
}

resource "google_storage_bucket_iam_member" "public_access_member" {
  bucket = google_storage_bucket.unencrypted_public_bucket.name
  role   = "roles/storage.objectViewer" # Permite a los usuarios ver objetos
  member = "allUsers"                  # Vulnerabilidad 1: Acceso público a todos los usuarios
}

# Vulnerabilidad 2: Falta de cifrado gestionado por el cliente (Customer-Managed Encryption Keys - CMEK)
# GCP Storage cifra por defecto con claves gestionadas por Google.
# La ausencia de un bloque 'encryption' aquí significa que no se está usando CMEK.
# En una configuración segura con CMEK, se añadiría un bloque como:
# encryption {
#   default_kms_key_name = "projects/your-project/locations/your-location/keyRings/your-keyring/cryptoKeys/your-key"
# }