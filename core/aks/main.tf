module "aks" {
  source             = "../../modules/aks"
  location           = "westus3"
  tenant_id          = "de5b2627-b190-44c6-a3dc-11c4294198e1"
  subscription_id    = "94476f39-40ea-4489-8831-da5475ccc163"
  firewall_whitelist = ["8.29.228.126", "8.29.109.138"]

  cluster_config = {
    "core" = {
      name                                = "aks-core-idp"
      sku_tier                            = "Free"
      dns_prefix                          = "akscoreidp"
      automatic_channel_upgrade           = "node-image"
      kubernetes_version                  = "1.29.4"
      oidc_issuer_enabled                 = true
      open_service_mesh_enabled           = false
      private_cluster_enabled             = true
      private_cluster_public_fqdn_enabled = true
      node_os_channel_upgrade             = "NodeImage"
      admin_group_object_ids              = "355b9c12-3bb2-4457-91cb-cdfe7afaa11f"

      default_node_pool = {
        name                         = "idpcore"
        zones                        = ["1"]
        os_disk_size_gb              = 128
        os_disk_type                 = "Ephemeral"
        orchestrator_version         = "1.29.4"
        vm_size                      = "Standard_DS2_v2"
        enable_auto_scaling          = true
        min_count                    = 1
        max_count                    = 3
        node_count                   = 1
        max_pods                     = 100
        enable_host_encryption       = true
        enable_node_public_ip        = true
        only_critical_addons_enabled = true
        kubelet_disk_type            = "Temporary"
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