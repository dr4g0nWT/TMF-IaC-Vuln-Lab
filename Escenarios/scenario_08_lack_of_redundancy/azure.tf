# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-08-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-08-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tfm-security-subnet-08-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  # No se especifica 'service_endpoints' para servicios específicos o delegaciones
}

resource "azurerm_network_interface" "nic" {
  name                = "tfm-security-nic-08-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "single_vm_app" {
  name                = "single-vm-app-08-azure"
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

  # Vulnerabilidad: No se despliega en un Availability Set ni se usa Zona de Disponibilidad
  # Esto deja la VM como un punto único de fallo dentro de la región.
  # availability_set_id = azurerm_availability_set.main.id # Comentado para la vulnerabilidad
  # zones = ["1"] # No se especifica una zona de disponibilidad explícita para redundancia
}

resource "azurerm_storage_account" "lrs_storage_account" {
  name                     = "tfmlrsstorage08" # Debe ser globalmente único
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  # Vulnerabilidad: Uso de LRS (Local-Redundant Storage) para datos críticos
  account_replication_type = "LRS" # ¡Vulnerabilidad! No es geo-redundante para DR
  # Para un entorno robusto se usaría GRS (Geo-Redundant) o ZRS (Zone-Redundant)
}

# Opcional: Para simular un Availability Set o una VM con zonas (comentado)
# resource "azurerm_availability_set" "main" {
#   name                = "tfm-availability-set-08"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   platform_fault_domain_count = 2
#   platform_update_domain_count = 2
#   managed = true
# }