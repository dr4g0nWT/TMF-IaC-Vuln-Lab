# Archivo: azure.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tfm-security-rg-06-azure"
  location = "West Europe" # Europa
}

# Vulnerabilidad: Azure Container Instance con puertos expuestos sin necesidad y sin límites de recursos
resource "azurerm_container_group" "insecure_container_aci" {
  name                = "tfm-insecure-aci-06"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  dns_name_label      = "insecureaci20250707" # Debe ser único globalmente
  os_type             = "Linux"

  container {
    name   = "insecure-web-app"
    image  = "nginx:latest" # Una imagen de ejemplo
    cpu    = 1
    memory = 1.5

    ports {
      port     = 80
      protocol = "TCP"
    }
    ports {
      port     = 3306 # Vulnerabilidad: Puerto de DB expuesto públicamente
      protocol = "TCP"
    }
    # No se especifican límites de recursos o políticas de reinicio robustas, aunque es más sutil
  }

  # Vulnerabilidad: No se configuran políticas de reinicio estrictas o seguridad avanzada
  # restart_policy = "OnFailure" # Más robusto sería "Never" o "OnFailure" con análisis
  # No hay "identity" para acceso a recursos seguros (Managed Identity)
  # No se monta Azure Files o otros volúmenes que podrían tener restricciones de seguridad
}

# Opcional: Cluster AKS con Pods inseguros (Requiere un setup más complejo)
# resource "azurerm_kubernetes_cluster" "aks_cluster" {
#   name                = "tfm-insecure-aks-cluster"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   dns_prefix          = "tfm-insecure-aks"
#
#   default_node_pool {
#     name       = "default"
#     node_count = 1
#     vm_size    = "Standard_DS2_v2"
#   }
#   service_principal {
#     client_id     = "" # Replace with your service principal client ID
#     client_secret = "" # Replace with your service principal client secret
#   }
# }
#
# # Para AKS, las vulnerabilidades se expresarían más en manifiestos de Kubernetes
# # (Deployment, Pods) que se aplicarían al cluster, por ejemplo:
# # - runAsUser: 0 (root)
# # - privileged: true
# # - allowPrivilegeEscalation: true
# # - hostPath mounts
# # - CAP_ADD: ALL
# # - exposed ports