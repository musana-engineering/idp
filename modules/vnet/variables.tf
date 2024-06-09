variable "location" {}
variable "firewall_whitelist" {}
variable "resource_group_name" {}
variable "private_dns_zones" { type = list(string) }

variable "container_service_features" {
  default = [
    "EnableAPIServerVnetIntegrationPreview",
    "KubeletDisk",
  "EnableEphemeralOSDiskPreview"]
}

variable "compute_features" {
  default = ["EncryptionAtHost"]
}

variable "tags" {
  type = map(string)
}

variable "subnets" {
  type = map(object({
    name                                          = string
    virtual_network_name                          = string
    address_prefixes                              = list(string)
    private_link_service_network_policies_enabled = bool
  }))
}

variable "virtual_networks" {
  type = map(object({
    name          = string
    address_space = list(string)
    dns_servers   = list(string)
  }))
}

variable "nat_gateways" {
  type = map(object({
    name              = string
    allocation_method = string
    sku_name          = string
  }))
}