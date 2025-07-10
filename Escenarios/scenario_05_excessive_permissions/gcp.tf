# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

# Vulnerabilidad: Service Account con rol de 'Editor' a nivel de proyecto
# El rol de 'Editor' otorga permisos de lectura/escritura para la mayoría de los recursos en el proyecto.
# Para una aplicación específica, este es un privilegio excesivo.
resource "google_service_account" "insecure_sa" {
  account_id   = "tfm-insecure-sa-2025"
  display_name = "Insecure Service Account with excessive permissions"
  project      = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_project_iam_member" "insecure_editor_binding" {
  project = google_service_account.insecure_sa.project
  role    = "roles/editor" # ¡Vulnerabilidad! Rol de Editor (permisos excesivos)
  member  = "serviceAccount:${google_service_account.insecure_sa.email}"
}

# Vulnerabilidad: Service Account con capacidad de actuar como otra Service Account (iam.serviceAccountUser)
# Esto, combinado con otros roles, puede llevar a una escalada de privilegios.
# Aquí, una SA tiene este permiso sobre otra SA que podría tener permisos sensibles.
resource "google_service_account" "target_sa" {
  account_id   = "tfm-target-sa-2025"
  display_name = "Target Service Account (potentially sensitive)"
  project      = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_service_account_iam_member" "insecure_sa_user_binding" {
  service_account_id = google_service_account.target_sa.name
  role               = "roles/iam.serviceAccountUser" # ¡Vulnerabilidad! Permite impersonar la SA
  member             = "serviceAccount:${google_service_account.insecure_sa.email}"
}