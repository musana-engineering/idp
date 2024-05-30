variable "location" {}
variable "firewall_whitelist" {}

variable "tags" {
  type = map(string)
}

variable "virtual_network_subnets" {
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