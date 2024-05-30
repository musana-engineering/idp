resource "azurerm_resource_group" "core" {
  name     = "RG-Core-idp"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "aks" {
  name     = "RG-Core-aks"
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_security_group" "nsg" {
  for_each            = var.virtual_network_subnets
  name                = "nsg-idp-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = var.tags

  lifecycle { ignore_changes = [tags] }

  depends_on = [azurerm_subnet.subnet, azurerm_virtual_network.vnet]
}

resource "azurerm_virtual_network" "vnet" {
  for_each            = var.virtual_networks
  name                = each.value.name
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  address_space       = each.value.address_space
  dns_servers         = each.value.dns_servers

  tags = var.tags
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_subnet" "subnet" {
  for_each                                      = var.virtual_network_subnets
  name                                          = each.value.name
  resource_group_name                           = azurerm_resource_group.core.name
  virtual_network_name                          = each.value.virtual_network_name
  address_prefixes                              = each.value.address_prefixes
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.ContainerRegistry",
    "Microsoft.AzureCosmosDB",
    "Microsoft.KeyVault",
    "Microsoft.ServiceBus",
    "Microsoft.EventHub",
    "Microsoft.AzureActiveDirectory",
  "Microsoft.Web"]
  lifecycle {
    ignore_changes = [private_link_service_network_policies_enabled]
  }

  depends_on = [azurerm_virtual_network.vnet]
}

data "azurerm_subnet" "aks" {
  name                 = "snet-aks-idp"
  virtual_network_name = "vnet-core-idp"
  resource_group_name  = azurerm_resource_group.core.name
  depends_on           = [azurerm_subnet.subnet, azurerm_virtual_network.vnet]
}

resource "azurerm_subnet_network_security_group_association" "nsg" {
  for_each                  = var.virtual_network_subnets
  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id

  depends_on = [azurerm_subnet.subnet, azurerm_network_security_group.nsg]
}

resource "azurerm_private_dns_zone" "core" {
  name                = "musana.engineering"
  resource_group_name = azurerm_resource_group.core.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "core" {
  for_each              = var.virtual_networks
  name                  = "vnet-core-idp"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.core.name
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
}

/*
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  for_each              = var.virtual_networks
  name                  = "vnet-${each.value.name}"
  resource_group_name   = "rg-rphubeastus2"
  private_dns_zone_name = "privatelink.blob.core.windows.net"
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  provider              = azurerm.hub
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  for_each              = var.virtual_networks
  name                  = "vnet-${each.value.name}"
  resource_group_name   = "rg-rphubeastus2"
  private_dns_zone_name = "privatelink.vaultcore.azure.net"
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  provider              = azurerm.hub

  tags = var.tags

  depends_on = [azurerm_virtual_network.vnet]
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "azurefile" {
  for_each              = var.virtual_networks
  name                  = "vnet-${each.value.name}"
  resource_group_name   = "rg-rphubeastus2"
  private_dns_zone_name = "privatelink.file.core.windows.net"
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  provider              = azurerm.hub
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  for_each              = var.virtual_networks
  name                  = "vnet-${each.value.name}"
  resource_group_name   = "rg-rphubeastus2"
  private_dns_zone_name = "privatelink.azurecr.io"
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  provider              = azurerm.hub
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
  lifecycle { ignore_changes = [tags] }
}
*/

