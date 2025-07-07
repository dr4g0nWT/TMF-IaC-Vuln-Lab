# Archivo: azure.tf

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-02-azure"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-02"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tfm-security-subnet-02"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "open_ports_nsg" {
  name                = "tfm-insecure-open-ports-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Vulnerabilidad 1: Acceso SSH desde cualquier lugar (0.0.0.0/0)
  security_rule {
    name                       = "AllowSSHFromAny"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # TODO: Esto es una vulnerabilidad (cualquier IP)
    destination_address_prefix = "*"
  }

  # Vulnerabilidad 2: Acceso RDP desde cualquier lugar (0.0.0.0/0)
  security_rule {
    name                       = "AllowRDPFromAny"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*" # TODO: Esto es una vulnerabilidad
    destination_address_prefix = "*"
  }

  # Vulnerabilidad 3: Acceso a un puerto de DB (ej. SQL Server) desde cualquier lugar (0.0.0.0/0)
  security_rule {
    name                       = "AllowSQLFromAny"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433" # Puerto por defecto de SQL Server
    source_address_prefix      = "*" # TODO: Esto es una vulnerabilidad
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Dev"
    Project     = "IaC_Security_TFM_Azure"
  }
}

# Opcional: Asociar el NSG a la subred o a una NIC
# resource "azurerm_subnet_network_security_group_association" "nsg_association" {
#   subnet_id                 = azurerm_subnet.subnet.id
#   network_security_group_id = azurerm_network_security_group.open_ports_nsg.id
# }