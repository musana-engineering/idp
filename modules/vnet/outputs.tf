output "vnet_id" {
  value = values(azurerm_virtual_network.vnet)[*].id
}

output "vnet_name" {
  value = values(azurerm_virtual_network.vnet)[*].name
}
