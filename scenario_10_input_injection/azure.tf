# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-10-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-10-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tfm-security-subnet-10-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "tfm-security-nic-10-azure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Variable de entrada para simular la entrada de usuario no validada
variable "untrusted_app_name" {
  description = "Simula un nombre de aplicación o parámetro de entrada no validado para cloud-init."
  type        = string
  default     = "webapp" # Valor por defecto
}

resource "azurerm_linux_virtual_machine" "insecure_cloud_init_vm" {
  name                = "insecure-cloud-init-vm-10-azure"
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

  # Vulnerabilidad: custom_data (cloud-init) que ejecuta directamente una variable sin sanitización
  # Un atacante podría inyectar comandos a través de 'untrusted_app_name'.
  custom_data = base64encode(<<EOF
              #cloud-config
              runcmd:
                - echo "Installing ${var.untrusted_app_name}..."
                # Este comando es vulnerable a inyección.
                # Si ${var.untrusted_app_name} fuera "nginx; rm -rf /", se ejecutaría.
                - apt-get update -y
                - apt-get install -y ${var.untrusted_app_name}
              EOF
  )
}