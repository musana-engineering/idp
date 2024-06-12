data "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-idp-core"
  resource_group_name = "RG-idp-aks"
}

data "azurerm_resource_group" "aks" {
  name = "RG-idp-aks"
}

data "azurerm_resource_group" "core" {
  name = "RG-core"
}

data "azurerm_user_assigned_identity" "mi" {
  name                = "mi-aks-idp-core"
  resource_group_name = data.azurerm_resource_group.aks.name
}

data "azurerm_key_vault" "kv" {
  name                = "kv-idp-core"
  resource_group_name = data.azurerm_resource_group.aks.name
}


data "azurerm_dns_zone" "azure_dns" {
  name                = "packetdance.com"
  resource_group_name = "RG-Core"
}
