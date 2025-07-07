# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-13-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-13-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "tfm-security-app-subnet-13-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "tfm-security-db-subnet-13-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Vulnerabilidad: Network Security Group (NSG) excesivamente permisivo a nivel de subred
resource "azurerm_network_security_group" "overly_permissive_nsg" {
  name                = "tfm-overly-permissive-nsg-13-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Vulnerabilidad 1: Regla de entrada que permite todo el tráfico (todos los puertos/protocolos) desde cualquier origen
  security_rule {
    name                       = "AllowAllInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*" # ¡Vulnerabilidad! Todos los protocolos
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*" # ¡Vulnerabilidad! Cualquier origen (incluyendo Internet)
    destination_address_prefix = "*"
  }

  # Vulnerabilidad 2: Regla de salida que permite todo el tráfico (todos los puertos/protocolos) a cualquier destino
  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*" # ¡Vulnerabilidad! Todos los protocolos
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*" # ¡Vulnerabilidad! Cualquier destino (incluyendo Internet)
  }

  tags = {
    Name = "TFM-Overly-Permissive-NSG-13"
  }
}

# Asociación del NSG vulnerable a las subredes
resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.overly_permissive_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.overly_permissive_nsg.id
}

# Un par de VMs para mostrar el efecto (la vulnerabilidad está en el NSG a nivel de subred)
resource "azurerm_network_interface" "app_nic" {
  name                = "tfm-app-nic-13-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "tfm-app-vm-13-azure"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.app_nic.id]
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
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsrXm...your_public_ssh_key... example@example.com"
  }
}