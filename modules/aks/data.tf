data "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.eastus2.azmk8s.io"
  resource_group_name = "RG-idp-core"
}

data "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = "RG-idp-core"
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "RG-idp-core"
}

data "azurerm_subnet" "aks" {
  name                 = "snet-idp-aks"
  virtual_network_name = "vnet-idp-core"
  resource_group_name  = "RG-idp-core"
}

data "azurerm_subnet" "controlplane" {
  name                 = "snet-aks-cplane"
  virtual_network_name = "vnet-idp-core"
  resource_group_name  = "RG-idp-core"
}

data "azurerm_virtual_network" "aks" {
  name                = "vnet-idp-core"
  resource_group_name = "RG-idp-core"
}