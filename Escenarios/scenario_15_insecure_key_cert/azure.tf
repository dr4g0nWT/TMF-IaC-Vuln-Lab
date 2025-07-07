# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-15-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-15-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tfm-security-subnet-15-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "tfm-public-ip-15-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "tfm-security-nic-15-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# --- Parte 1: Máquina virtual con disco del SO no encriptado ---
resource "azurerm_linux_virtual_machine" "unencrypted_os_disk_vm" {
  name                = "tfm-unencrypted-disk-vm-15-azure"
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
    # No se especifica 'disk_encryption_set_id', lo que significa que el disco no está encriptado con CMK
    # y por defecto solo utiliza la encriptación en el servicio de almacenamiento (SSE).
    # Para simular la vulnerabilidad, se asume que no se está utilizando encriptación a nivel de disco completo (ADE).
    # Explicitamente sin encriptación:
    # write_accelerator_enabled = false # No relacionado con encriptación pero aquí para contexto
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsrXm...your_public_ssh_key... example@example.com"
  }
  tags = {
    Name = "TFM-Unencrypted-OS-Disk-VM"
  }
}

# --- Parte 2: Application Gateway que permite HTTP ---
resource "azurerm_public_ip" "app_gw_public_ip" {
  name                = "tfm-appgw-public-ip-15"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "insecure_app_gateway" {
  name                = "tfm-insecure-appgw-15"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "default-config"
    subnet_id = azurerm_subnet.subnet.id # Asume una subred para el AG
  }

  frontend_ip_configuration {
    name                 = "frontendipconfig"
    public_ip_address_id = azurerm_public_ip.app_gw_public_ip.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  # Vulnerabilidad 2: Listener para HTTP (puerto 80) sin redirección a HTTPS
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontendipconfig"
    frontend_port_name             = "http-port"
    protocol                       = "Http" # ¡Vulnerabilidad! Permite tráfico HTTP sin cifrar
  }

  backend_address_pool {
    name = "backendpool"
  }

  backend_http_settings {
    name                  = "backendhttpsettings"
    port                  = 80
    protocol              = "Http"
    cookie_based_affinity = "Disabled"
    request_timeout       = 20
  }

  request_routing_rule {
    name                        = "routing-rule"
    rule_type                   = "Basic"
    http_listener_name          = "http-listener"
    backend_address_pool_name   = "backendpool"
    backend_http_settings_name  = "backendhttpsettings"
  }

  tags = {
    Name = "TFM-Insecure-App-Gateway"
  }
}