# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-18-azure"
  location = "West Europe" # Europa
}

# --- Contexto: VM y red para el backend ---
resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-18-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "tfm-security-app-subnet-18-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "tfm-vm-public-ip-18"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "tfm-vm-nic-18"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "backend_vm" {
  name                = "tfm-backend-vm-18"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.vm_nic.id]

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

# --- Vulnerabilidad 1: Application Gateway sin SKU de WAF ---
resource "azurerm_public_ip" "app_gw_public_ip" {
  name                = "tfm-appgw-public-ip-18"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_subnet" "app_gw_subnet" {
  name                 = "tfm-appgw-subnet-18"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_application_gateway" "insecure_app_gateway" {
  name                = "tfm-insecure-appgw-18"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name = "Standard_v2" # ¡Vulnerabilidad! No se usa "WAF_v2" SKU
    tier = "Standard_v2" # O "WAF_v2" para habilitar WAF
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "default-config"
    subnet_id = azurerm_subnet.app_gw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "frontendipconfig"
    public_ip_address_id = azurerm_public_ip.app_gw_public_ip.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontendipconfig"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  backend_address_pool {
    name = "backendpool"
    ip_addresses = [azurerm_public_ip.vm_public_ip.ip_address] # O la IP privada de la VM
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

  # La ausencia de un bloque 'waf_configuration' es la vulnerabilidad.
  # waf_configuration {
  #   enabled            = true
  #   firewall_mode      = "Prevention"
  #   rule_set_type      = "OWASP"
  #   rule_set_version   = "3.1"
  # }

  tags = {
    Name = "TFM-Insecure-App-Gateway"
  }
}

# --- Vulnerabilidad 2: CDN Profile/Endpoint que permite HTTP y no fuerza HTTPS ---
resource "azurerm_cdn_profile" "insecure_cdn_profile" {
  name                = "tfm-insecure-cdn-profile-18"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_Microsoft" # O "Standard_Verizon", "Premium_Verizon"
}

resource "azurerm_cdn_endpoint" "insecure_cdn_endpoint" {
  name                = "tfm-insecure-cdn-endpoint-18-${random_id.cdn_suffix.hex}"
  profile_name        = azurerm_cdn_profile.insecure_cdn_profile.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  origin {
    name = "backend-vm-origin"
    host_header = azurerm_public_ip.vm_public_ip.ip_address # O el FQDN de la VM
    # La vulnerabilidad es que este origen directo es accesible
    # Si la VM tuviera una IP privada, el CDN la resolvería si estuviera en la misma VNet o en un VNet Peering.
    # Para la simulación, usamos la IP pública de la VM.
    # La VM es el "origen" que el CDN cachea y sirve.
  }

  is_http_allowed         = true  # ¡Vulnerabilidad! Permite el acceso a través de HTTP
  is_https_allowed        = true
  # No se especifica 'default_origin_group' con un grupo que tenga HTTPS enforcement.
  # No hay reglas de ruta para forzar HTTPS.
  # No hay 'delivery_rule' para la redirección HTTPS.

  tags = {
    Name = "TFM-Insecure-CDN-Endpoint"
  }
}

resource "random_id" "cdn_suffix" {
  byte_length = 4
}

output "app_gateway_public_ip" {
  value = azurerm_public_ip.app_gw_public_ip.ip_address
  description = "Public IP of the Application Gateway (no WAF)."
}

output "cdn_endpoint_hostname" {
  value = azurerm_cdn_endpoint.insecure_cdn_endpoint.host_name
  description = "Hostname of the CDN endpoint (allows HTTP)."
}