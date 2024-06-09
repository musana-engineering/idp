resource "azurerm_resource_group" "aks" {
  name     = "RG-idp-aks"
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_registry" "acr" {
  name                = "acridpcore"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_storage_account" "sa" {
  name                          = "saaksidpcore"
  resource_group_name           = azurerm_resource_group.aks.name
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
  name                = "saaksidpcore"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  subnet_id           = data.azurerm_subnet.aks.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob.id]
  }
  private_service_connection {
    name                           = "saaksidpcore"
    private_connection_resource_id = azurerm_storage_account.sa.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "aks" {
  location            = var.location
  name                = "mi-aks-idp-core"
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "contributor" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "Contributor"
  scope                = "/subscriptions/${var.subscription_id}"

  depends_on = [azurerm_user_assigned_identity.aks]
}

resource "azurerm_role_assignment" "mi-identity-operator" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "Managed Identity Operator"
  scope                = "/subscriptions/${var.subscription_id}"

  depends_on = [azurerm_user_assigned_identity.aks]
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "loga-core-idp"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_key_vault" "aks" {
  name                        = "kv-idp-core"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.aks.name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  enable_rbac_authorization   = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.firewall_whitelist
    virtual_network_subnet_ids = [data.azurerm_subnet.aks.id]
  }
  tags = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  for_each            = var.cluster_config
  name                = "kv-idp-core"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  subnet_id           = data.azurerm_subnet.aks.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.kv.id]
  }
  private_service_connection {
    name                           = "kv-idp-core"
    private_connection_resource_id = azurerm_key_vault.aks.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [subnet_id]
  }
}

resource "azurerm_role_assignment" "dns" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "Private DNS Zone Contributor"
  scope                = data.azurerm_private_dns_zone.aks.id

  depends_on = [azurerm_user_assigned_identity.aks]
}

resource "azurerm_role_assignment" "vnet" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "Network Contributor"
  scope                = data.azurerm_virtual_network.aks.id

  depends_on = [azurerm_user_assigned_identity.aks]
}

resource "azurerm_role_assignment" "kv" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.aks.id

  depends_on = [azurerm_user_assigned_identity.aks,
  azurerm_key_vault.aks]
}

resource "azurerm_role_assignment" "acr" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
  depends_on = [azurerm_user_assigned_identity.aks,
  azurerm_key_vault.aks]
}

resource "azurerm_role_assignment" "acmebot_secrets_officer" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = azurerm_key_vault.aks.id
  depends_on           = [azurerm_user_assigned_identity.aks]
}

resource "azurerm_role_assignment" "acmebot_crypto_officer" {
  for_each             = var.cluster_config
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  role_definition_name = "Key Vault Crypto Officer"
  scope                = azurerm_key_vault.aks.id
  depends_on           = [azurerm_user_assigned_identity.aks]
}

// AKS Cluster
resource "azurerm_proximity_placement_group" "aks" {
  name                = "ppg-idp-core"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  zone                = "1"
  allowed_vm_sizes = ["Standard_DS2_v2", "Standard_D8s_v5", "Standard_D16s_v5", "Standard_D4s_v5",
    "Standard_D2s_v5", "Standard_D32s_v5", "Standard_DS4_v2", "Standard_DS5_v2",
    "Standard_DS3_v2", "Standard_E8bds_v5", "Standard_E16bds_v5", "Standard_E4bds_v5",
    "Standard_D8s_v3", "Standard_D4s_v3", "Standard_D16s_v3", "Standard_D32s_v3", "Standard_D48s_v3",
    "Standard_B1ls", "Standard_B1ms", "Standard_B1s", "Standard_B2ms",
  "Standard_B2s", "Standard_B4ms", "Standard_B8ms", "Standard_B12ms"]

  tags = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  for_each                  = var.cluster_config
  name                      = each.value.name
  location                  = var.location
  sku_tier                  = each.value.sku_tier
  resource_group_name       = azurerm_resource_group.aks.name
  dns_prefix                = each.value.dns_prefix
  automatic_channel_upgrade = each.value.automatic_channel_upgrade
  azure_policy_enabled      = true
  workload_identity_enabled = true
  kubernetes_version        = each.value.kubernetes_version
  node_resource_group       = "${azurerm_resource_group.aks.name}-nodes"
  oidc_issuer_enabled       = each.value.oidc_issuer_enabled
  open_service_mesh_enabled = each.value.open_service_mesh_enabled
  private_cluster_enabled   = each.value.private_cluster_enabled
  #  private_dns_zone_id                 = data.azurerm_private_dns_zone.aks.id
  private_cluster_public_fqdn_enabled = each.value.private_cluster_public_fqdn_enabled
  role_based_access_control_enabled   = true
  run_command_enabled                 = true
  image_cleaner_enabled               = true
  image_cleaner_interval_hours        = 96
  local_account_disabled              = false
  node_os_channel_upgrade             = each.value.node_os_channel_upgrade

  api_server_access_profile {
    subnet_id                = data.azurerm_subnet.controlplane.id
    vnet_integration_enabled = true
    authorized_ip_ranges     = var.firewall_whitelist
  }

  linux_profile {
    admin_username = "rundeck"
    ssh_key {
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCeq9GxVIMjU7LxpPT+OGxM3MWUdz/DREtRLL+44Gewr+da7swtMY/2h5sLwF308ZNOiWwaW2Zo0JfqevejPsecnYjZGP5FDuuHcQwm8ZWhWOOJvI2d72NVS/DrIOunKHwfQfkUZpZSGa7plIgFVjSWeHo4Ng2g3bGOTLh3wl7vHV/162WPeIYWxeZnktu7FqVPqeXr5G79uwBRr+Q4ojWNE31/XDKfsPMGIR6RhW4PcJTUEHdW5w6wImo5wPbCTlG4EgC1VZvS5wKFgE0w7pnMhPAxzr5vdjChZEtNqnAjdLY6b20gh1xcw+eRXPklFq2lGTgH6xP9pWr9M6zPC71JI8m4V1spTi7WUOfRKEUBga2QhryrQ7e4yfoO16+0+1gqYGDoIQZd28WtV+qO+5K/2iepMJ3Q5p8Mp626PfYMv+pzm+SdXSNjs52xLYCX+n8xQiUuhfsjIWdVXKpILelXXAaOP/qUhzAoVYVDrWLYL9ItQfZu2wRCnqIJ8/juK6k= root@bastion"
    }
  }

  auto_scaler_profile {
    balance_similar_node_groups  = true
    expander                     = "random"
    max_graceful_termination_sec = 600
  }

  storage_profile {
    blob_driver_enabled = false
    disk_driver_enabled = false
    file_driver_enabled = false
    #    disk_driver_version         = "v2"
    snapshot_controller_enabled = true
  }

  #  microsoft_defender {
  #    log_analytics_workspace_id = data.azurerm_log_analytics_workspace.aks.id
  #  }

  #  oms_agent {
  #    log_analytics_workspace_id      = data.azurerm_log_analytics_workspace.aks.id
  #    msi_auth_for_monitoring_enabled = true
  # }

  #  monitor_metrics {
  #
  #  }

  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = ["1"]
    }
  }

  maintenance_window_auto_upgrade {
    frequency    = "AbsoluteMonthly"
    start_time   = "6:00"
    utc_offset   = "-05:00"
    interval     = 1
    duration     = "4"
    day_of_week  = "Monday"
    day_of_month = 1
    week_index   = "First"
  }

  maintenance_window_node_os {
    frequency    = "AbsoluteMonthly"
    start_time   = "6:00"
    utc_offset   = "-05:00"
    interval     = 1
    duration     = "4"
    day_of_week  = "Monday"
    day_of_month = 2
    week_index   = "First"
  }

  #  azure_active_directory_role_based_access_control {
  #    tenant_id              = var.tenant_id
  #    azure_rbac_enabled     = true
  #    managed = false
  #    admin_group_object_ids = each.value.admin_group_object_ids
  #  }

  default_node_pool {
    name                         = each.value.default_node_pool.name
    zones                        = each.value.default_node_pool.zones
    type                         = "VirtualMachineScaleSets"
    os_disk_size_gb              = each.value.default_node_pool.os_disk_size_gb
    os_disk_type                 = each.value.default_node_pool.os_disk_type
    orchestrator_version         = each.value.default_node_pool.orchestrator_version
    vm_size                      = each.value.default_node_pool.vm_size
    vnet_subnet_id               = data.azurerm_subnet.aks.id
    enable_auto_scaling          = each.value.default_node_pool.enable_auto_scaling
    min_count                    = each.value.default_node_pool.min_count
    max_count                    = each.value.default_node_pool.max_count
    node_count                   = each.value.default_node_pool.node_count
    enable_host_encryption       = each.value.default_node_pool.enable_host_encryption
    enable_node_public_ip        = each.value.default_node_pool.enable_node_public_ip
    max_pods                     = each.value.default_node_pool.max_pods
    only_critical_addons_enabled = each.value.default_node_pool.only_critical_addons_enabled
    kubelet_disk_type            = each.value.default_node_pool.kubelet_disk_type
    os_sku                       = each.value.default_node_pool.os_sku
    proximity_placement_group_id = azurerm_proximity_placement_group.aks.id
    scale_down_mode              = "Delete"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.aks.client_id
    object_id                 = azurerm_user_assigned_identity.aks.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks.id
  }

  network_profile {
    network_plugin      = "azure"
    network_policy      = "cilium"
    network_mode        = "transparent"
    ebpf_data_plane     = "cilium"
    network_plugin_mode = "overlay"
    outbound_type       = "userAssignedNATGateway"

    #    nat_gateway_profile {
    #      
    #    }

  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.vnet,
    azurerm_role_assignment.dns,
    azurerm_role_assignment.vnet,
    azurerm_role_assignment.mi-identity-operator,
    azurerm_key_vault.aks,
    azurerm_proximity_placement_group.aks,
    azurerm_private_endpoint.kv,
    azurerm_user_assigned_identity.aks,
    azurerm_role_assignment.vnet,
    azurerm_resource_group.aks
  ]
lifecycle {
  ignore_changes = [ default_node_pool]
}
}
