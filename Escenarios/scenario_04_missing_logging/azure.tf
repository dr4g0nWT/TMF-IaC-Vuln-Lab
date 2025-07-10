# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-04-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-04-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tfm-security-subnet-04-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "tfm-security-nic-04-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_without_diagnostic_settings" {
  name                = "unlogged-linux-vm-04-azure"
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

  # Vulnerabilidad: No se adjunta una extensión de diagnóstico (ej. Azure Monitor Agent)
  # ni se configuran los 'boot_diagnostics' o 'identity' para el envío de logs.
  # En una configuración segura, se usaría 'azurerm_monitor_diagnostic_setting'.
  # boot_diagnostics {
  #   storage_account_uri = azurerm_storage_account.diag_storage.primary_blob_endpoint
  # }
}

resource "azurerm_storage_account" "unlogged_storage_account" {
  name                     = "tfmunloggedstorage04" # Debe ser globalmente único
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Vulnerabilidad: No se configura el logging de diagnóstico para la cuenta de almacenamiento
  # En una configuración segura, se usaría 'azurerm_monitor_diagnostic_setting'
  # para enviar logs de operaciones a un Log Analytics Workspace o Storage Account.
}

# Un Log Analytics Workspace para comparar, si se habilitara el logging de diagnóstico
# resource "azurerm_log_analytics_workspace" "workspace" {
#   name                = "tfm-log-workspace-04"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   sku                 = "PerGB2018"
# }

# Ejemplo de cómo sería la configuración de diagnóstico (comentada para la vulnerabilidad)
# resource "azurerm_monitor_diagnostic_setting" "storage_diag" {
#   name                       = "tfm-storage-diagnostic-setting"
#   target_resource_id         = azurerm_storage_account.unlogged_storage_account.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id
#
#   log {
#     category = "StorageRead"
#     enabled  = true
#
#     retention_policy {
#       enabled = true
#       days    = 30
#     }
#   }
#   metric {
#     category = "Transaction"
#     enabled  = true
#
#     retention_policy {
#       enabled = true
#       days    = 30
#     }
#   }
# }