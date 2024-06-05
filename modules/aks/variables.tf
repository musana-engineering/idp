variable "location" {}
variable "tags" {}
variable "firewall_whitelist" {}
variable "tenant_id" {}
variable "subscription_id" {}
variable "virtual_network_resource_group_name" {}
variable "virtual_network_name" {}
variable "aks_subnet_name" {}
variable "aks_control_plane_subnet_name" {}

variable "cluster_config" {
  type = map(object({
    name                                = string
    sku_tier                            = string
    dns_prefix                          = string
    automatic_channel_upgrade           = string
    kubernetes_version                  = string
    oidc_issuer_enabled                 = string
    open_service_mesh_enabled           = string
    private_cluster_enabled             = string
    private_cluster_public_fqdn_enabled = string
    node_os_channel_upgrade             = string
    admin_group_object_ids              = list(string)
    default_node_pool = object({
      name                         = string
      zones                        = list(string)
      os_disk_size_gb              = number
      os_disk_type                 = string
      orchestrator_version         = string
      vm_size                      = string
      enable_auto_scaling          = bool
      min_count                    = number
      max_count                    = number
      node_count                   = number
      max_pods                     = number
      enable_host_encryption       = bool
      enable_node_public_ip        = bool
      only_critical_addons_enabled = bool
      kubelet_disk_type            = string
      os_sku                       = string
    })
  }))
}