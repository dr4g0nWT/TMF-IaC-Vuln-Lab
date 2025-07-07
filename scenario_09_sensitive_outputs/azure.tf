# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-09-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-09-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tfm-security-subnet-09-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "tfm-security-nic-09-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "random_password" "db_password" {
  length  = 16
  special = true
  numeric = true
  upper   = true
  lower   = true
}

resource "azurerm_mysql_server" "mysql_server" {
  name                = "tfm-mysqlserver-09" # Debe ser único globalmente
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "B_Gen5_1"
  storage_mb          = 5120
  version             = "8.0"
  administrator_login    = "mysqladmin"
  administrator_login_password = random_password.db_password.result # Usa la contraseña generada
  ssl_enforcement_enabled = true
}

resource "azurerm_linux_virtual_machine" "insecure_vm" {
  name                = "insecure-linux-vm-09-azure"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsrXm...your_public_ssh_key... example@example.com" # Cambia si vas a desplegar
  }
}

# Vulnerabilidad: Exponer la contraseña del administrador de la base de datos en un output
output "mysql_admin_password_exposed" {
  value       = random_password.db_password.result # ¡Vulnerabilidad! Contraseña de DB expuesta
  description = "Contiene la contraseña del administrador de MySQL. ¡No debe ser expuesta!"
  sensitive   = false
}

# Vulnerabilidad: Exponer la cadena de conexión completa de la base de datos en un output
output "mysql_connection_string_exposed" {
  value = "Server=${azurerm_mysql_server.mysql_server.fqdn}; Port=3306; Database=your_database; Uid=${azurerm_mysql_server.mysql_server.administrator_login}; Pwd=${random_password.db_password.result}; SslMode=Required;" # ¡Vulnerabilidad! Cadena de conexión con credenciales expuestas
  description = "Cadena de conexión completa para el servidor MySQL. Contiene la contraseña."
  sensitive   = false
}