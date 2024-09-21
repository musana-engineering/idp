module "aks" {
  source                              = "../../modules/aks"
  location                            = "westus3"
  tenant_id                           = ""
  subscription_id                     = ""
  firewall_whitelist                  = ["54.39.28.200", "54.39.137.255"]
  virtual_network_name                = "vnet-idp-core"
  aks_subnet_name                     = "snet-idp-aks"
  aks_control_plane_subnet_name       = "snet-aks-cplane"
  virtual_network_resource_group_name = "RG-idp-net"

  cluster_config = {
    "core" = {
      name                                = "aks-idp-core"
      sku_tier                            = "Free"
      dns_prefix                          = "aksidpcore"
      automatic_channel_upgrade           = "node-image"
      kubernetes_version                  = "1.29.4"
      oidc_issuer_enabled                 = true
      open_service_mesh_enabled           = false
      private_cluster_enabled             = false
      private_cluster_public_fqdn_enabled = false
      node_os_channel_upgrade             = "NodeImage"
      admin_group_object_ids              = ["355b9c12-3bb2-4457-91cb-cdfe7afaa11f"]

      default_node_pool = {
        name                         = "idpcore"
        zones                        = ["1"]
        os_disk_size_gb              = 80
        os_disk_type                 = "Ephemeral"
        orchestrator_version         = "1.29.4"
        vm_size                      = "Standard_DS2_v2"
        enable_auto_scaling          = true
        min_count                    = 1
        max_count                    = 3
        node_count                   = 3
        max_pods                     = 100
        enable_host_encryption       = true
        enable_node_public_ip        = true
        only_critical_addons_enabled = true
        kubelet_disk_type            = "OS"
        os_sku                       = "AzureLinux"
      }
    }
  }

  tags = {
    provisioner = "terraform"
    location    = "westus3"
    project     = "idp"
  }
}

