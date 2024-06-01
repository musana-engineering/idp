variable "location" {}
variable "tags" {}
variable "firewall_whitelist" {}
variable "tenant_id" {}

variable "cluster_config" {
  type = map(object({
    name                                = string
    location                            = string
    tags                                = map(string)
    subscription_id                     = string
    tenant_id                           = string
    firewall_whitelist                  = list(string)
    virtual_network_subnet_ids          = list(string)
    sku_tier                            = string
    dns_prefix                          = string
    automatic_channel_upgrade           = string
    kubernetes_version                  = string
    oidc_issuer_enabled                 = string
    open_service_mesh_enabled           = string
    private_cluster_enabled             = string
    private_cluster_public_fqdn_enabled = string
    node_os_channel_upgrade             = string
    admin_group_object_ids              = string
  }))
}