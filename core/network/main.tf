locals {
  firewall_whitelist = ["8.29.228.126", "8.29.109.138"]
  location           = "westus3"

  tags = {
    provisioner = "terraform"
    location    = "westus3"
    project     = "idp"
  }
}

module "network" {
  source              = "../../modules/vnet"
  tags                = local.tags
  location            = local.location
  firewall_whitelist  = local.firewall_whitelist
  resource_group_name = "RG-idp-net"

  private_dns_zones = [
    "privatelink.blob.core.windows.net",
    "privatelink.westus3.azmk8s.io",
    "privatelink.vaultcore.azure.net",
  "musana.engineering"]

  virtual_networks = {
    
    "core" = {
      name          = "vnet-idp-core"
      address_space = ["10.141.0.0/16"]
      dns_servers   = ["168.63.129.16"]
    }
  }

  nat_gateways = {

    "core" = {
      name              = "natgw-idp-core"
      allocation_method = "Static"
      sku_name          = "Standard"
      subnet_id         = data.azurerm_subnet.aks.id
    }
  }

  subnets = {

    "aks" = {
      name                                          = "snet-idp-aks"
      virtual_network_name                          = "vnet-idp-core"
      address_prefixes                              = ["10.141.0.0/17"]
      private_endpoint_network_policies_enabled     = true
      private_link_service_network_policies_enabled = true
    }

    "controlplane" = {
      name                                          = "snet-aks-cplane"
      virtual_network_name                          = "vnet-idp-core"
      address_prefixes                              = ["10.141.129.0/28"]
      private_endpoint_network_policies_enabled     = true
      private_link_service_network_policies_enabled = true
    }
  }
}
