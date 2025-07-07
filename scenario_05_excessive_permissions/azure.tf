# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-05-azure"
  location = "West Europe" # Europa
}

# Vulnerabilidad: Asignación de rol de 'Owner' a un Service Principal
# Otorga permisos excesivos a una aplicación o servicio.
resource "azurerm_user_assigned_identity" "insecure_managed_identity" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name                = "tfm-insecure-managed-identity-2025"
}

resource "azurerm_role_assignment" "insecure_owner_assignment" {
  scope                = azurerm_resource_group.rg.id # Asigna a nivel de Resource Group
  role_definition_name = "Owner"                      # ¡Vulnerabilidad! Rol de propietario
  principal_id         = azurerm_user_assigned_identity.insecure_managed_identity.principal_id
}

# Vulnerabilidad: Asignación de rol de 'Contributor' a un grupo de seguridad de red
# Este ejemplo es menos común directamente, pero simula un rol con amplios permisos de escritura/modificación
# sobre recursos de red, cuando quizás solo se necesite ver o aplicar configuraciones.
# Se crea un 'Network Contributor' para un grupo de seguridad de red hipotético.
resource "azurerm_network_security_group" "test_nsg" {
  name                = "tfm-test-nsg-05"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Se asume la existencia de un Service Principal ID o un Object ID para un usuario/grupo
# que recibirá este rol. Para el laboratorio, usaremos una identidad gestionada para simplificar.
resource "azurerm_user_assigned_identity" "insecure_network_identity" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name                = "tfm-insecure-network-identity-2025"
}

resource "azurerm_role_assignment" "insecure_network_contributor_assignment" {
  scope                = azurerm_network_security_group.test_nsg.id # Asigna a nivel de NSG
  role_definition_name = "Network Contributor"                       # ¡Vulnerabilidad!
  principal_id         = azurerm_user_assigned_identity.insecure_network_identity.principal_id
}