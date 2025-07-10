# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-20-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-20-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "tfm-security-vm-subnet-20-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "vm_public_ip" {
  name                = "tfm-vm-public-ip-20"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "tfm-vm-nic-20"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

# --- Vulnerabilidad: VM con Custom Data que expone información sensible ---
resource "azurerm_linux_virtual_machine" "insecure_azure_vm" {
  name                = "tfm-insecure-azure-vm-20"
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

  # ¡Vulnerabilidad! Contiene información sensible en Custom Data.
  # Aunque Custom Data es para la propia VM, puede ser recuperado por actores maliciosos
  # si comprometen la VM o el servicio de metadatos de la VM.
  custom_data = base64encode(<<EOF
              #!/bin/bash
              echo "WEBHOOK_URL=https://insecure.webhook.site/mysecretdata" > /etc/app/sensitive_info.conf
              echo "INTERNAL_DB_PASS=WeakPass123" >> /etc/app/sensitive_info.conf
              EOF
  )

  tags = {
    Name = "TFM-Insecure-Azure-VM-Metadata"
  }
}

# Opcional: Para el IMDS de Azure, no hay un control directo sobre la versión como en AWS.
# La vulnerabilidad estaría en cómo el código dentro de la VM accede al IMDS o si se loguea.
# Otro vector es la exposición de Boot Diagnostics a una cuenta de almacenamiento pública.
resource "azurerm_storage_account" "boot_diagnostics_storage" {
  name                     = "tfmbootdiag20${random_id.diag_suffix.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  # ¡Vulnerabilidad! No está configurado para acceso privado o con CORS restrictivo
  # Si este bucket fuera público o CORS muy abierto, los logs/capturas de pantalla podrían ser expuestos.
}

resource "random_id" "diag_suffix" {
  byte_length = 4
}

# Habilitar Boot Diagnostics para la VM (que escribe en el storage account)
resource "azurerm_virtual_machine_extension" "boot_diagnostics_extension" {
  name                 = "BootDiagnostics"
  virtual_machine_id   = azurerm_linux_virtual_machine.insecure_azure_vm.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureDiagnostics"
  type_handler_version = "1.1"

  settings = <<SETTINGS
    {
      "storageAccountName": "${azurerm_storage_account.boot_diagnostics_storage.name}",
      "storageAccountSasToken": ""
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "storageAccountAccessKey": "${azurerm_storage_account.boot_diagnostics_storage.primary_access_key}"
    }
  PROTECTED_SETTINGS

  tags = {
    purpose = "boot_diagnostics"
  }
}

output "vm_public_ip" {
  value = azurerm_public_ip.vm_public_ip.ip_address
  description = "Public IP of the insecure Azure VM. Custom data contains sensitive info."
}
output "boot_diagnostics_storage_account_name" {
  value = azurerm_storage_account.boot_diagnostics_storage.name
  description = "Storage account for boot diagnostics. Review its public access settings."
}