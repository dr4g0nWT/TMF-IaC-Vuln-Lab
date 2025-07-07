# Archivo: azure_storage.tf

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-01"
  location = "West Europe"
}

resource "azurerm_storage_account" "insecure_storage_account" {
  name                     = "insecurestorageacc20250707" # Debe ser globalmente único
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Vulnerabilidad 1: Acceso público permitido a los blobs
  # Habilita el acceso anónimo a contenedores y blobs.
  # Aunque la configuración a nivel de contenedor/blob es lo que finalmente controla el acceso,
  # a nivel de cuenta, esto permite la posibilidad de configuraciones públicas.
  # En producción, esto debería ser 'false' o no estar presente si se busca el acceso privado por defecto.
  allow_blob_public_access = true 

  # Vulnerabilidad 2: No se especifica Customer-Managed Key (CMK) para el cifrado
  # Azure Storage está cifrado por defecto con claves gestionadas por Microsoft.
  # Sin embargo, para mayor seguridad y cumplimiento, a menudo se recomienda CMK.
  # La ausencia de este bloque podría ser una alerta para herramientas que busquen cumplimiento.
  # customer_managed_key {
  #   key_vault_id        = "/subscriptions/xxxxx/resourceGroups/yyyyy/providers/Microsoft.KeyVault/vaults/zzzzz"
  #   key_name            = "mykey"
  #   key_version         = "12345"
  #   user_assigned_identity_id = "/subscriptions/xxxxx/resourcegroups/yyyyy/providers/Microsoft.ManagedIdentity/userAssignedIdentities/iiiiii"
  # }
}

resource "azurerm_storage_container" "public_container" {
  name                  = "public-data"
  storage_account_name  = azurerm_storage_account.insecure_storage_account.name
  container_access_type = "blob" # Vulnerabilidad 1: Acceso de lectura público a blobs

  depends_on = [azurerm_storage_account.insecure_storage_account]
}