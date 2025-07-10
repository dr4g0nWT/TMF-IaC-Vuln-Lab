# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-19-azure"
  location = "West Europe" # Europa
}

resource "azurerm_storage_account" "st" {
  name                     = "tfmsecst19${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "storage_suffix" {
  byte_length = 4
}

resource "azurerm_app_service_plan" "app_plan" {
  name                = "tfm-security-app-plan-19"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

# --- Vulnerabilidad 1: Function App con Managed Identity excesivamente permisiva ---
resource "azurerm_function_app" "insecure_function_app" {
  name                       = "tfm-insecure-funcapp-19"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.app_plan.id
  storage_account_name       = azurerm_storage_account.st.name
  storage_account_access_key = azurerm_storage_account.st.primary_access_key
  version                    = "~4" # Versión de runtime, usar una compatible

  identity {
    type = "SystemAssigned" # Habilita la Managed Identity
  }

  tags = {
    Name = "TFM-Insecure-Function-App"
  }
}

# ¡Vulnerabilidad! Asignar un rol de "Owner" o "Contributor" a la identidad gestionada.
resource "azurerm_role_assignment" "insecure_funcapp_owner_assignment" {
  scope                = azurerm_resource_group.rg.id # O incluso azurerm_subscription.current.id
  role_definition_name = "Owner" # ¡Grave vulnerabilidad! Permisos de control total
  principal_id         = azurerm_function_app.insecure_function_app.identity[0].principal_id
}

# --- Vulnerabilidad 2: Application Settings con información sensible ---
resource "azurerm_function_app_slot" "insecure_app_settings" {
  name                = "production" # Slot predeterminado
  function_app_id     = azurerm_function_app.insecure_function_app.id
  resource_group_name = azurerm_resource_group.rg.name

  app_settings = {
    DATABASE_CONNECTION_STRING = "Server=myinsecure.database.windows.net;Database=data;User ID=admin;Password=BadPassword123;" # ¡Grave vulnerabilidad!
    SENDGRID_API_KEY           = "SG.insecure_api_key_xyz"
  }
  lifecycle {
    ignore_changes = [
      app_settings, # Ignorar cambios si se gestionan por fuera (ej. CI/CD)
    ]
  }
}