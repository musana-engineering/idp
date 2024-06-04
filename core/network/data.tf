data "azurerm_subnet" "aks" {
  name                 = "snet-idp-aks"
  virtual_network_name = "vnet-idp-core"
  resource_group_name  = "RG-idp-net"
}