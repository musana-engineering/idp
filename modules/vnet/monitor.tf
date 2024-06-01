resource "azurerm_network_watcher" "watcher" {
  for_each            = var.virtual_networks
  name                = "netw-core-idp"
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name

  tags = var.tags
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "loga-core-idp"
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

/*
resource "azurerm_network_watcher_flow_log" "logs" {
  for_each             = var.virtual_network_subnets
  network_watcher_name = "netw-core-idp"
  resource_group_name  = azurerm_resource_group.core.name
  name                 = each.value.name
  version              = 2

  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
  storage_account_id        = azurerm_storage_account.sa.id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 15
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.aks.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.aks.location
    workspace_resource_id = azurerm_log_analytics_workspace.aks.id
    interval_in_minutes   = 60
  }

  depends_on = [azurerm_network_watcher.watcher,
    azurerm_network_security_group.nsg,
    azurerm_virtual_network.vnet,
    azurerm_subnet.subnet,
    azurerm_storage_account.sa
  ]

  tags = var.tags
}
*/

resource "azurerm_storage_account" "sa" {
  name                          = "sacoreidp"
  resource_group_name           = azurerm_resource_group.core.name
  location                      = var.location
  account_tier                  = "Standard"
  large_file_share_enabled      = true
  account_replication_type      = "LRS"
  enable_https_traffic_only     = true
  is_hns_enabled                = true
  public_network_access_enabled = true

  network_rules {
    virtual_network_subnet_ids = ["${data.azurerm_subnet.aks.id}"]
    default_action             = "Deny"
    ip_rules                   = var.firewall_whitelist
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [network_rules]
  }
}

resource "azurerm_private_endpoint" "sa" {
  name                = "sacoreidp"
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location
  subnet_id           = data.azurerm_subnet.aks.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.core.id]
  }
  private_service_connection {
    name                           = "sacoreidp"
    private_connection_resource_id = azurerm_storage_account.sa.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags       = var.tags
  depends_on = [azurerm_private_dns_zone.core, azurerm_subnet.subnet]
}

