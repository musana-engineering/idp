resource "azurerm_resource_group" "core" {
  name     = "RG-idp-core"
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_security_group" "nsg" {
  for_each            = var.virtual_network_subnets
  name                = "snet-idp-aks"
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
  name                 = "snet-idp-aks"
  virtual_network_name = "vnet-idp-core"
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

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.core.name
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.eastus2.azmk8s.io"
  resource_group_name = azurerm_resource_group.core.name
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.core.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "core" {
  for_each              = var.virtual_networks
  name                  = "vnet-idp-core"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.core.name
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  for_each              = var.virtual_networks
  name                  = "vnet-idp-core"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  for_each              = var.virtual_networks
  name                  = "vnet-idp-core"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  for_each              = var.virtual_networks
  name                  = "vnet-idp-core"
  resource_group_name   = azurerm_resource_group.core.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet[each.key].id
  tags                  = var.tags
  depends_on            = [azurerm_virtual_network.vnet]
}

