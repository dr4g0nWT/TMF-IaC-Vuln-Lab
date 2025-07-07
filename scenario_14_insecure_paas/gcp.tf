# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

# Crear un servicio de Cloud Functions con acceso no autenticado
resource "google_cloud_run_service" "cloud_function_service" { # Cloud Functions v2 usa Cloud Run Service
  name     = "tfm-insecure-function-14"
  location = "europe-west1"
  project  = "your-gcp-project-id"

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Imagen de ejemplo simple
    }
  }
  traffic {
    percent = 100
    latest_revision = true
  }
}

# Vulnerabilidad 1: Permitir la invocación no autenticada para el servicio de Cloud Function/Run
resource "google_cloud_run_service_iam_member" "allow_unauthenticated_invocation" {
  service  = google_cloud_run_service.cloud_function_service.name
  location = google_cloud_run_service.cloud_function_service.location
  project  = google_cloud_run_service.cloud_function_service.project
  role     = "roles/run.invoker"
  member   = "allUsers" # ¡Vulnerabilidad! Permite invocación por cualquier usuario sin autenticación
}

output "cloud_function_url" {
  value       = google_cloud_run_service.cloud_function_service.uri
  description = "La URL del Cloud Function/Run Service. ¡Acceso público no autenticado!"
}

# --- Simulación de API Gateway expuesto sin autenticación ---
# Para simplificar, se crea un API Gateway que expone una función Cloud (o un backend HTTP)
# sin requerir ninguna autenticación para la invocación del API Gateway.

resource "google_api_gateway_api" "insecure_api_gw_14" {
  provider = google-beta # API Gateway a menudo requiere el proveedor beta
  api_id   = "tfm-insecure-api-14"
  project  = "your-gcp-project-id"
}

resource "google_api_gateway_api_config" "insecure_api_gw_config_14" {
  provider = google-beta
  api      = google_api_gateway_api.insecure_api_gw_14.api_id
  api_config_id = "default" # Puede ser 'default' o un nombre específico

  gateway_config {
    backend_config {
      google_service_account = "service-${replace(data.google_project.project.number, "-", "")}@gcp-sa-apigateway.iam.gserviceaccount.com" # Default service account
    }
  }

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = <<-EOF
                  swagger: '2.0'
                  info:
                    title: Insecure API
                    description: API expuesta públicamente sin seguridad
                    version: 1.0.0
                  schemes:
                    - https
                  produces:
                    - application/json
                  paths:
                    /greeting:
                      get:
                        summary: Get a greeting
                        x-google-backend:
                          address: ${google_cloud_run_service.cloud_function_service.uri} # Apunta a la función insegura
                          protocol: h2
                        responses:
                          '200':
                            description: A greeting message.
                  securityDefinitions:
                    # Ausencia de definiciones de seguridad o apiKey/oauth2 aplicadas
                    # La vulnerabilidad es la falta de configuración para exigir seguridad.
                    # Por defecto, los endpoints pueden ser públicos si no se configuran con requisitos.
                  EOF
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [google_cloud_run_service.cloud_function_service]
}

data "google_project" "project" {
  project_id = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}

resource "google_api_gateway_gateway" "insecure_api_gateway_deployment_14" {
  provider      = google-beta
  gw_id         = "tfm-insecure-gateway-14"
  api_config    = google_api_gateway_api_config.insecure_api_gw_config_14.id
  project       = "your-gcp-project-id"
  region        = "europe-west1" # Debe coincidir con la región del API Config
}

output "api_gateway_public_url" {
  value       = google_api_gateway_gateway.insecure_api_gateway_deployment_14.default_hostname
  description = "La URL del API Gateway expuesto. ¡Acceso público sin autenticación!"
}