# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-11-azure"
  location = "West Europe" # Europa
}

resource "random_password" "db_password" {
  length  = 16
  special = true
  numeric = true
  upper   = true
  lower   = true
}

resource "azurerm_mysql_server" "insecure_mysql_server" {
  name                = "tfm-mysqlserver-insecure-11" # Debe ser único globalmente
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "B_Gen5_1"
  storage_mb          = 5120
  version             = "8.0"
  administrator_login    = "mysqladmin"
  administrator_login_password = random_password.db_password.result # Usar Key Vault en producción
  ssl_enforcement_enabled = false # ¡Vulnerabilidad! SSL/TLS deshabilitado
}

# Vulnerabilidad 1: Regla de firewall que permite el acceso público
resource "azurerm_mysql_firewall_rule" "public_access_rule" {
  name                = "AllowAllPublicAccess"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_server.insecure_mysql_server.name
  start_ip_address    = "0.0.0.0" # ¡Vulnerabilidad!
  end_ip_address      = "255.255.255.255" # ¡Vulnerabilidad!
}

# Vulnerabilidad 2: Configuración de red virtual no usada o no restringida
# La base de datos no está configurada para usar puntos de conexión de servicio de VNet
# o Private Link, lo que la deja expuesta a la IP pública.
# azurerm_mysql_server.insecure_mysql_server.public_network_access_enabled = true # Esto es por defecto si no se configura VNet.