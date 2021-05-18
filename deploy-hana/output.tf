output "instance_id_hana" {
  description = "ID of instance HANA"
  value       = azurerm_linux_virtual_machine.my_vm.id
}

output "network_private_ip_hana" {
  description = "Private IP of network interface of HANA"
  value       = azurerm_network_interface.my_network_interface_hana.private_ip_address
}

output "admin_username" {
  description = "Admin user for remote login."
  value       = azurerm_linux_virtual_machine.my_vm.admin_username
}

output "default_location" {
  description = "Locations for creation of objects."
  value       = local.default_location
}

output "default_storage_name" {
  description = "Storage account in use."
  value       = local.default_storage_name
}

output "network_public_ip_hana" {
  description = "Public IP of network interface of HANA"
  value       = azurerm_public_ip.my_public_ip.*.ip_address
}
