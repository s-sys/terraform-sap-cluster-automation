output "instance_id_hana" {
  description = "ID of SAP instances"
  value       = azurerm_linux_virtual_machine.sap_vm.*.id
}

output "network_private_ip_sap" {
  description = "Private IP of network interface of SAP VMs"
  value       = azurerm_network_interface.my_network_interface_sap.*.private_ip_address
}

output "admin_username" {
  description = "Admin user for remote login."
  value       = azurerm_linux_virtual_machine.sap_vm.0.admin_username
}

output "default_location" {
  description = "Locations for creation of objects."
  value       = local.default_location
}

output "default_storage_name" {
  description = "Storage account in use."
  value       = local.default_storage_name
}

output "network_public_ip_sap" {
  description = "Public IP of network interface of SAP VMs"
  value       = azurerm_public_ip.my_public_ip.*.ip_address
}

output "lb_ip_sap" {
  description = "IP of load balancer"
  value       = (tobool(var.create_lb) == true && tobool(var.create_lb_public_ip) == true) ? azurerm_public_ip.my_lb_public_ip[0].ip_address : azurerm_lb.my_lb[0].frontend_ip_configuration[0].private_ip_address
}

output "azuread_application_id_login" {
  description = "AzureAD application ID"
  value       = tobool(var.create_fencing_app) == true ? azuread_application.azuread_app[0].application_id : data.azuread_application.azuread_app[0].application_id
}

output "azuread_application_password" {
  description = "AzureAD application password"
  value       = tobool(var.create_fencing_app) == true ? azuread_application_password.azuread_app_password[0].value : "USE EXISTING PASSWORD"
  sensitive   = true
}

output "azuread_resource_group" {
  description = "Resource Group used in Azure"
  value       = local.default_rg_name
}

output "azuread_application_tenant_id" {
  description = "AzureAD Tenant ID from application"
  value       = data.azurerm_subscription.current.tenant_id
}

output "azuread_application_subscription_id" {
  description = "AzureAD Subscription ID from application"
  value       = data.azurerm_subscription.current.subscription_id
}
