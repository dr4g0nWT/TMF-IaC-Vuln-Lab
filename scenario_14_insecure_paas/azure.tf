# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-14-azure"
  location = "West Europe" # Europa
}

resource "azurerm_application_insights" "app_insights" {
  name                = "tfm-appinsights-14"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "tfmstorageacc14${random_id.storage_suffix.hex}" # Nombre debe ser único globalmente
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "storage_suffix" {
  byte_length = 8
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "tfm-app-service-plan-14"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  sku {
    tier = "Consumption" # Plan de consumo para Functions
    size = "Y1"
  }
}

resource "azurerm_function_app" "insecure_function_app" {
  name                       = "tfm-insecure-func-app-14-${random_id.app_suffix.hex}" # Nombre debe ser único globalmente
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
  }
  https_only                 = false # ¡Vulnerabilidad! No forzar HTTPS
}

resource "random_id" "app_suffix" {
  byte_length = 4
}

# Asumiendo una función HTTP Trigger. El código no está en Terraform, pero la configuración sí.
# Vulnerabilidad: Azure Function con nivel de autorización "Anonymous"
# Esto se define en el código de la función (function.json), no directamente en Terraform.
# Sin embargo, Terraform permite la exposición de la URL de la función.
output "insecure_function_url" {
  value = "${azurerm_function_app.insecure_function_app.default_hostname}/api/HttpTrigger1?code=YOUR_FUNCTION_KEY" # Asumiendo una función HTTP Trigger
  # Si la función tiene AuthorizationLevel.Anonymous, 'code' no es necesario.
  description = "URL de la función Azure. Si la función tiene authLevel 'Anonymous', es accesible públicamente sin clave."
}

# --- Simulación de API Management expuesto ---
# En Azure API Management, la exposición se controla principalmente a través
# de las políticas (policies) y la configuración de API.
# Aquí simulamos una API Management básica sin seguridad de API implementada por defecto.

resource "azurerm_api_management" "api_management" {
  name                = "tfm-apim-insecure-14-${random_id.api_suffix.hex}" # Nombre debe ser único globalmente
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "TFMPublisher"
  publisher_email     = "tfm@example.com"
  sku_name            = "Developer_1" # Developer SKU para pruebas
}

resource "random_id" "api_suffix" {
  byte_length = 4
}

resource "azurerm_api_management_api" "insecure_api" {
  name                = "tfm-insecure-api-14"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.api_management.name
  revision            = "1"
  display_name        = "Insecure Public API"
  path                = "insecure"
  protocols           = ["https", "http"] # ¡Vulnerabilidad! Permitir HTTP
  service_url         = azurerm_function_app.insecure_function_app.default_hostname # Backend es la Function App
}

# Vulnerabilidad: Política global que no impone seguridad (ej. no requiere suscripción)
# Esto se haría en el archivo XML de políticas, pero se puede inferir por la ausencia de configuración.
# Para simular, podríamos omitir cualquier política de seguridad de entrada.
# Sin un `azurerm_api_management_api_policy` que restrinja el acceso,
# la API podría estar expuesta por defecto si no se requiere una clave de suscripción o JWT.
# Por defecto, se requiere una clave de suscripción si no se configura de otra manera.
# La vulnerabilidad sería si no se usa `subscription_required = true` en la API (que es por defecto)
# o si se sobrescriben las políticas para permitir acceso anónimo.