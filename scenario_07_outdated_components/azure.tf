# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-07-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-07-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tfm-security-subnet-07-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "tfm-security-nic-07-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "outdated_vm" {
  name                = "outdated-linux-vm-07-azure"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  # Vulnerabilidad 1: Uso de una imagen de SO antigua/específica que no está actualizada
  # Aquí se usa una versión específica (16.04-LTS) que ya no recibe soporte general.
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS" # ¡Vulnerabilidad! Versión antigua y fuera de soporte
    version   = "latest"   # 'latest' para esta SKU antigua sigue siendo una versión 16.04
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsrXm...your_public_ssh_key... example@example.com" # Cambia si vas a desplegar
  }

  # Vulnerabilidad 2: No hay configuración de Azure Update Management ni de auto-parcheo
  # En un entorno seguro, se adjuntaría la VM a un Automation Account con Update Management
  # No hay extensión para actualizaciones de paquetes automatizadas
  # No hay "patch_mode" definido en el os_disk para actualizaciones automáticas (disponible para Windows)
  # No se especifica la instalación automática de actualizaciones de seguridad en 'custom_data'
}