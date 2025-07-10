# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-16-azure"
  location = "West Europe" # Europa
}

# Simulación: Crear una identidad gestionada por el usuario con permisos excesivos
# en recursos fuera de su ámbito normal o con acceso de federación débil.
# Una identidad gestionada suele ser para servicios, pero puede ser un vector si tiene demasiados permisos.

resource "azurerm_user_assigned_identity" "insecure_managed_identity" {
  name                = "tfm-insecure-managed-identity-16"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  tags = {
    Name = "TFM-Insecure-Managed-Identity"
  }
}

# Vulnerabilidad 1: Otorgar rol de "Colaborador" (Contributor) a una identidad gestionada
# en el nivel del grupo de recursos (o incluso la suscripción), violando el principio de mínimo privilegio.
# Esto es especialmente riesgoso si esta identidad se usa en una VM/App Service expuesta.
resource "azurerm_role_assignment" "insecure_role_assignment_rg_scope" {
  scope                = azurerm_resource_group.rg.id # O incluso azurerm_subscription.current.id
  role_definition_name = "Contributor" # ¡Vulnerabilidad! Acceso excesivo
  principal_id         = azurerm_user_assigned_identity.insecure_managed_identity.principal_id
}

# Simulación 2: Crear una aplicación AAD (Service Principal) con permisos delegados o de aplicación amplios.
# Terraform no puede directamente configurar permisos delegados/de aplicación para un SP en AAD.
# Esto se manejaría más a menudo a través de la GUI o Azure CLI/PowerShell para evitar secretos en código.
# Sin embargo, podemos simular la creación de un SP y la asignación de un rol excesivo.

resource "azuread_application" "insecure_app" {
  display_name = "tfm-insecure-aad-app-16"
}

resource "azuread_service_principal" "insecure_sp" {
  application_id = azuread_application.insecure_app.application_id
  # Para simular una federación insegura, podríamos imaginar que esta SP
  # se usa desde otro tenant con credenciales débiles o expuestas.
}

# Vulnerabilidad 2: Asignar a un Service Principal el rol de "Owner" a nivel de grupo de recursos o superior.
resource "azurerm_role_assignment" "insecure_sp_owner_assignment" {
  scope                = azurerm_resource_group.rg.id # O incluso azurerm_subscription.current.id
  role_definition_name = "Owner" # ¡Vulnerabilidad! Control total
  principal_id         = azuread_service_principal.insecure_sp.id
}