# Archivo: gcp.tf

provider "google" {
  project = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  region  = "europe-west1"         # Bélgica, Europa
}

resource "google_sql_database_instance" "insecure_cloud_sql_db" {
  project          = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
  name             = "tfm-insecure-cloud-sql-11"
  database_version = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
    # disk_autoresize = true
    # backup_configuration {
    #   enabled            = true
    #   binary_log_enabled = true
    # }

    ip_configuration {
      # Vulnerabilidad 1: Habilitar la IP pública para la base de datos
      ipv4_enabled = true # ¡Vulnerabilidad! DB accesible públicamente

      # Vulnerabilidad 2: Redes autorizadas excesivamente permisivas (0.0.0.0/0)
      authorized_networks {
        value = "0.0.0.0/0" # ¡Vulnerabilidad! Acceso desde cualquier IP
        name  = "Public Access"
      }

      # Vulnerabilidad 3: No forzar el uso de SSL/TLS
      # require_ssl = false # Ausencia o configuración explícita a false
    }

    # Vulnerabilidad 4: Contraseña de usuario raíz débil o no cambiada (ya cubierta en S3, pero importante aquí)
    # No se especifica un password para el usuario 'root', que puede usar el usuario por defecto.
    # user_labels = {} # No hay etiquetas que puedan indicar configuraciones de seguridad.
  }
}

resource "google_sql_user" "insecure_db_user" {
  name     = "insecure_user"
  instance = google_sql_database_instance.insecure_cloud_sql_db.name
  host     = "%" # ¡Vulnerabilidad! Usuario accesible desde cualquier host
  password = "VeryWeakPassword1!" # ¡Vulnerabilidad! Contraseña débil
  project  = "your-gcp-project-id" # ¡CAMBIA ESTO A TU ID DE PROYECTO REAL!
}