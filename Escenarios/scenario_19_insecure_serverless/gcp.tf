# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

# --- Contexto: Bucket para el código de la función ---
resource "google_storage_bucket" "function_code_bucket" {
  name          = "tfm-function-code-19-${random_id.bucket_suffix.hex}"
  location      = "EUROPE-WEST1"
  force_destroy = true
  project       = "your-gcp-project-id"
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "google_storage_bucket_object" "function_zip" {
  name   = "function.zip"
  bucket = google_storage_bucket.function_code_bucket.name
  source = data.archive_file.function_source.output_path
}

data "archive_file" "function_source" {
  type        = "zip"
  output_path = "function_source.zip"
  source_content = "exports.handler = (req, res) => { console.log('Received request:', req); res.status(200).send('Hello from Cloud Function!'); };"
}

# --- Vulnerabilidad 1: Cloud Function con cuenta de servicio excesivamente permisiva ---
resource "google_service_account" "insecure_function_sa" {
  account_id   = "tfm-insecure-func-sa-19"
  display_name = "TFM Insecure Cloud Function SA"
  project      = "your-gcp-project-id"
}

# ¡Vulnerabilidad! Asignar un rol de "Editor" o "Propietario" a la cuenta de servicio de la función.
resource "google_project_iam_member" "insecure_sa_project_editor" {
  project = "your-gcp-project-id"
  role    = "roles/editor" # ¡Grave vulnerabilidad! Permisos de editor a nivel de proyecto
  member  = "serviceAccount:${google_service_account.insecure_function_sa.email}"
}

# --- Vulnerabilidad 2: Cloud Function con información sensible en variables de entorno ---
resource "google_cloudfunctions_function" "insecure_cloud_function" {
  name        = "tfm-insecure-cloud-function-19"
  runtime     = "nodejs16" # Usar una versión de runtime compatible
  entry_point = "handler"
  region      = "europe-west1"
  project     = "your-gcp-project-id"

  source_archive_bucket = google_storage_bucket.function_code_bucket.name
  source_archive_object = google_storage_bucket_object.function_zip.name
  
  service_account_email = google_service_account.insecure_function_sa.email

  trigger_http = true # Para hacerla invocable vía HTTP

  # ¡Vulnerabilidad! Almacenar secretos directamente en variables de entorno.
  environment_variables = {
    DATABASE_USERNAME = "admin"
    DATABASE_PASSWORD = "AnotherHardcodedSecret123!" # ¡Grave vulnerabilidad!
    THIRD_PARTY_API_KEY = "XYZ_GCP_Insecure_Key"
  }
  labels = {
    environment = "dev-insecure"
  }
}

# Opcional: Permitir invocación pública (si trigger_http=true, se puede hacer más permisivo)
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.insecure_cloud_function.project
  region         = google_cloudfunctions_function.insecure_cloud_function.region
  cloud_function = google_cloudfunctions_function.insecure_cloud_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers" # ¡Vulnerabilidad! Cualquier persona puede invocar la función.
}

output "cloud_function_url" {
  value = google_cloudfunctions_function.insecure_cloud_function.https_trigger_url
  description = "URL of the insecure Cloud Function."
}