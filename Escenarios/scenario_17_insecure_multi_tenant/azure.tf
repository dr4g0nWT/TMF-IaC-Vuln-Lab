# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-17-azure"
  location = "West Europe" # Europa
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tfm-security-vnet-17-azure"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "tfm-security-aks-subnet-17-azure"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- Vulnerabilidad: AKS con Network Policy deshabilitada o demasiado permisiva ---
resource "azurerm_kubernetes_cluster" "insecure_aks_cluster" {
  name                = "tfm-insecure-aks-cluster-17"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "tfm-aks-17"
  kubernetes_version  = "1.27" # Versión de ejemplo, usar una compatible
  sku_tier            = "Free" # O Basic/Standard

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure" # CNI de Azure
    # ¡Vulnerabilidad! La ausencia de 'network_policy' o configurarlo a 'none'
    # significa que las políticas de red de Kubernetes no se aplicarán,
    # permitiendo comunicación por defecto entre pods de diferentes namespaces/inquilinos.
    network_policy     = "none" # ¡Vulnerabilidad! Deshabilita las políticas de red para aislamiento
    # network_policy = "calico" # Si se habilitara Calico, la vulnerabilidad sería la *ausencia* de las políticas K8s.
  }

  # Endpoint del servidor de API público por defecto si no se configura 'private_cluster_enabled'
  # private_cluster_enabled = false # Por defecto, si no se especifica.

  tags = {
    Name = "TFM-Insecure-AKS-Cluster"
  }
}