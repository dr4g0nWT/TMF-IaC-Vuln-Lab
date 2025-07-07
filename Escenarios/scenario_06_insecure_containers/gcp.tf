# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_project_service" "container_api" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  service = "run.googleapis.com"
  disable_on_destroy = false
}

# Vulnerabilidad: Cloud Run service con privilegios amplios (si no se especifica el service account)
# y sin una configuración de seguridad granular (ej. no usando 'securityContext' como en K8s).
# Cloud Run gestiona muchos aspectos de la seguridad, pero se puede introducir una SA con exceso de permisos.
resource "google_cloud_run_service" "insecure_cloud_run" {
  name     = "tfm-insecure-cloud-run-06"
  location = "europe-west1" # Debe ser una región de Cloud Run

  template {
    spec {
      containers {
        image = "gcr.io/cloudrun/hello" # Imagen de ejemplo
        ports {
          container_port = 8080
        }
        # No se especifica 'runAsUser' o 'readOnlyRootFilesystem' como en Kubernetes,
        # ya que Cloud Run abstrae estas opciones. La vulnerabilidad aquí recaería
        # en el service account asociado o en la falta de límites explícitos.
        # env {
        #   name  = "DEBUG_MODE"
        #   value = "true" # Una variable de entorno que podría exponer información
        # }
      }
      # service_account_name = google_service_account.insecure_cloud_run_sa.email # Si no se especifica, usa la SA por defecto del proyecto, que podría tener Editor/Owner
    }
  }

  traffic {
    percent     = 100
    latest_revision = true
  }

  # Vulnerabilidad: Acceso público y sin autenticación forzada
  # La configuración 'ingress' por defecto es "all" (todos).
  # Para un servicio interno, esto sería una vulnerabilidad.
  # metadata.annotations."run.googleapis.com/ingress" = "all"

  depends_on = [google_project_service.container_api]
}

# Un Service Account con permisos excesivos que podría ser usado por Cloud Run
resource "google_service_account" "insecure_cloud_run_sa" {
  account_id   = "tfm-insecure-cr-sa-06"
  display_name = "Insecure Cloud Run Service Account"
  project      = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_project_iam_member" "cloud_run_sa_editor_binding" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  role    = "roles/editor" # ¡Vulnerabilidad! Editor a nivel de proyecto
  member  = "serviceAccount:${google_service_account.insecure_cloud_run_sa.email}"
}

# Opcional: Para Kubernetes Engine (GKE), las vulnerabilidades se expresan en los manifiestos de K8s
# resource "google_container_cluster" "primary" {
#   name     = "tfm-insecure-gke-cluster"
#   location = "europe-west1"
#   initial_node_count = 1
# }
#
# # Y luego, los manifiestos de K8s con Pods que tendrían securityContext:
# #   privileged: true
# #   runAsUser: 0
# #   allowPrivilegeEscalation: true
# #   hostNetwork: true
# #   hostPID: true
# #   capabilities:
# #     add: ["NET_ADMIN", "SYS_ADMIN"]