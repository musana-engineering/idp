data "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-idp-core"
  resource_group_name = "RG-idp-aks"
}

data "azurerm_resource_group" "rg" {
  name = "RG-idp-aks"
}

data "azurerm_user_assigned_identity" "mi" {
  name                = "mi-aks-idp-core"
  resource_group_name = data.azurerm_resource_group.rg.name
}