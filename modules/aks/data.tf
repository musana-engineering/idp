data "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.westus3.azmk8s.io"
  resource_group_name = var.virtual_network_resource_group_name
}

data "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.virtual_network_resource_group_name
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.virtual_network_resource_group_name
}

data "azurerm_subnet" "aks" {
  name                 = var.aks_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group_name
}

data "azurerm_subnet" "controlplane" {
  name                 = var.aks_control_plane_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.virtual_network_resource_group_name
}

data "azurerm_virtual_network" "aks" {
  name                = var.virtual_network_name
  resource_group_name = var.virtual_network_resource_group_name
}

