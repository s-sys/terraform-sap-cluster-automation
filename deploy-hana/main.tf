# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

# Get Azure subscription
data "azurerm_subscription" "current" {
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id == "" ? null : var.subscription_id
  tenant_id       = var.tenant_id == "" ? null : var.client_secret
  client_id       = var.client_id == "" ? null : var.client_id
  client_secret   = var.client_secret == "" ? null : var.client_secret
}

locals {
  default_rg_name      = var.resource_group != "" ? var.resource_group : "hana-rg"
  default_location     = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].location : var.location
  default_vnet_name    = var.vnet_name != "" ? var.vnet_name : "vnet"
  default_subnet_name  = var.subnet_name != "" ? var.subnet_name : "subnet"

  # Storage account
  storage_data         = split(":", var.storage_account)
  storage_account      = local.storage_data[0]
  storage_rg           = local.storage_data[1]
  default_storage_name = local.storage_account != "" ? local.storage_account : "diag${random_id.randomId.hex}"

  # HANA image
  hana_img_data  = split(":", var.vm_hana_image)
  hana_publisher = local.hana_img_data[0]
  hana_offer     = local.hana_img_data[1]
  hana_sku       = local.hana_img_data[2]
  hana_version   = local.hana_img_data[3]

  # Hana disks
  disks_number      = length(var.hana_disks["disks_size"]) == 0 ? 0 : length(split(",", var.hana_disks["disks_size"]))
  disks_size        = local.disks_number > 0 ? ([for disk_size in split(",", var.hana_disks["disks_size"]) : tonumber(trimspace(disk_size))]) : null
  disks_type        = local.disks_number > 0 ? ([for disk_type in split(",", var.hana_disks["disks_type"]) : trimspace(disk_type)]) : null
  disks_caching     = local.disks_number > 0 ? ([for caching in split(",", var.hana_disks["caching"]) : trimspace(caching)]) : null
  disks_write_accel = local.disks_number > 0 ? ([for writeaccelerator in split(",", var.hana_disks["writeaccelerator"]) : tobool(trimspace(writeaccelerator))]) : null
  disks_luns        = local.disks_number > 0 ? ([for lun in split(",", var.hana_disks["luns"]) : tonumber(trimspace(lun))]) : null
  disks_names       = local.disks_number > 0 ? ([for name in split(",", var.hana_disks["names"]) : trimspace(name)]) : null
  disks_paths       = local.disks_number > 0 ? ([for path in split(",", var.hana_disks["paths"]) : trimspace(path)]) : null

  # NSG 
  nsg_size                       = length(var.nsg_rules["name"]) > 0 ? length(split(",", var.nsg_rules["name"])) : 0 
  nsg_rule_name                  = local.nsg_size > 0 ? ([for name in split(",", var.nsg_rules["name"]) : trimspace(name)]) : null
  nsg_direction                  = local.nsg_size > 0 ? ([for direction in split(",", var.nsg_rules["direction"]) : trimspace(direction)]) : null
  nsg_access                     = local.nsg_size > 0 ? ([for access in split(",", var.nsg_rules["access"]) : trimspace(access)]) : null
  nsg_protocol                   = local.nsg_size > 0 ? ([for protocol in split(",", var.nsg_rules["protocol"]) : trimspace(protocol)]) : null
  nsg_source_port_range          = local.nsg_size > 0 ? ([for source_port_range in split(",", var.nsg_rules["source_port_range"]) : trimspace(source_port_range)]) : null
  nsg_destination_port_range     = local.nsg_size > 0 ? ([for destination_port_range in split(",", var.nsg_rules["destination_port_range"]) : trimspace(destination_port_range)]) : null
  nsg_source_address_prefix      = local.nsg_size > 0 ? ([for source_address_prefix in split(",", var.nsg_rules["source_address_prefix"]) : trimspace(source_address_prefix)]) : null
  nsg_destination_address_prefix = local.nsg_size > 0 ? ([for destination_address_prefix in split(",", var.nsg_rules["destination_address_prefix"]) : trimspace(destination_address_prefix)]) : null
  nsg_priority_base              = 2000
}

# Set cloud-init file to run
data  "template_file" "config_hana" {
  template = file(var.cloudinit_hana)

  vars = {
    vm_hana_name              = var.vm_hana_name
    vm_hana_swap_size         = var.vm_hana_swap_size
    vm_hana_reg_code          = var.vm_hana_reg_code
    vm_hana_reg_email         = var.vm_hana_reg_email
    hana_private_ip           = azurerm_network_interface.my_network_interface_hana.private_ip_address
    disks_number              = local.disks_number
    disks_paths               = replace(var.hana_disks["paths"], ",", " ")
    hana_media_local          = var.hana_media_local
    hana_media_storage        = var.hana_media_storage
    hana_media_key            = var.hana_media_key
    hana_media_add_fstab      = var.hana_media_add_fstab
    storage_account           = local.storage_account
    admin_password            = var.admin_password
    hana_install_packages     = var.hana_install_packages
    hana_software_path        = var.hana_software_path
    hana_monitoring_enabled   = var.hana_monitoring_enabled
    hana_sid                  = var.hana_sid
    hana_instance             = var.hana_instance
    hana_password             = var.hana_password
    hana_system_user_password = var.hana_system_user_password
    hana_sapadm_password      = var.hana_sapadm_password
    monit_exposition_port     = var.monit_exposition_port
    monit_multi_tenant        = var.monit_multi_tenant
    monit_user                = var.monit_user
    monit_port                = var.monit_port
    monit_timeout             = var.monit_timeout
  }
}

data "template_cloudinit_config" "config_hana" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.config_hana.rendered
  }
}

data "azurerm_resource_group" "my_resource_group" {
  count = var.resource_group != "" ? 1 : 0
  name  = var.resource_group
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "my_resource_group" {
  count    = var.resource_group != "" ? 0 : 1
  name     = local.default_rg_name
  location = local.default_location
}

# Use existing virtual network
data "azurerm_virtual_network" "my_virtual_network" {
  count               = var.vnet_name != "" ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
}

# Create virtual network
resource "azurerm_virtual_network" "my_virtual_network" {
  count               = var.vnet_name != "" ? 0 : 1
  name                = local.default_vnet_name
  address_space       = [var.vnet_addr]
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
}

# Use existing subnet network
data "azurerm_subnet" "my_subnet" {
  count                = var.subnet_name != "" ? 1 : 0
  name                 = var.subnet_name
  resource_group_name  = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  virtual_network_name = var.subnet_name != "" ? data.azurerm_virtual_network.my_virtual_network[0].name : azurerm_virtual_network.my_virtual_network[0].name
}

# Create subnet
resource "azurerm_subnet" "my_subnet" {
  count                = var.subnet_name != "" ? 0 : 1
  name                 = var.subnet_name
  resource_group_name  = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  virtual_network_name = var.subnet_name != "" ? data.azurerm_virtual_network.my_virtual_network[0].name : azurerm_virtual_network.my_virtual_network[0].name
  address_prefixes     = [var.subnet_addr]
}

resource "azurerm_public_ip" "my_public_ip" {
  count               = tobool(var.vm_hana_pub_ip) == true ? 1 : 0
  name                = "hana_public_ip_${count.index}"
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  allocation_method   = "Dynamic"
}

# Create Network Security Group
data "azurerm_network_security_group" "my_nsg" {
  count               = length(var.nsg_name) > 0 ? 1 : 0
  name                = var.nsg_name
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
}

resource "azurerm_network_security_group" "my_nsg" {
  count               = length(var.nsg_name) > 0 ? 0 : 1
  name                = "nsg"
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
}

# Create Network Security rules
resource "azurerm_network_security_rule" "my_nsg_rule" {
  count                       = local.nsg_size > 0 ? local.nsg_size : 0
  name                        = local.nsg_rule_name[count.index]
  priority                    = local.nsg_priority_base + count.index
  direction                   = local.nsg_direction[count.index]
  access                      = local.nsg_access[count.index]
  protocol                    = local.nsg_protocol[count.index]
  source_port_range           = local.nsg_source_port_range[count.index]
  destination_port_range      = local.nsg_destination_port_range[count.index]
  source_address_prefix       = local.nsg_source_address_prefix[count.index]
  destination_address_prefix  = local.nsg_destination_address_prefix[count.index]
  resource_group_name         = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  network_security_group_name = length(var.nsg_name) > 0 ? data.azurerm_network_security_group.my_nsg[0].name : azurerm_network_security_group.my_nsg[0].name
}

# Create network interface for SUMA
resource "azurerm_network_interface" "my_network_interface_hana" {
  name                          = "hana_nic"
  location                      = local.default_location
  resource_group_name           = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  enable_accelerated_networking = var.vm_hana_net_accel

  ip_configuration {
    name                          = "nic_configuration"
    subnet_id                     = var.subnet_name != "" ? data.azurerm_subnet.my_subnet[0].id : azurerm_subnet.my_subnet[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm_hana_ip
    public_ip_address_id          = tobool(var.vm_hana_pub_ip) == true ? azurerm_public_ip.my_public_ip[0].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "my_network_nsg_association_hana" {
  network_interface_id      = azurerm_network_interface.my_network_interface_hana.id
  network_security_group_id = length(var.nsg_name) > 0 ? data.azurerm_network_security_group.my_nsg[0].id : azurerm_network_security_group.my_nsg[0].id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  }

  byte_length = 8
}

# Use existing storage account
data "azurerm_storage_account" "my_storage_account" {
  count               = (local.storage_account != "" && local.storage_rg != "") ? 1 : 0
  name                = local.storage_account
  resource_group_name = local.storage_rg 
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  count                       = (var.vm_hana_boot_diag == true && local.storage_account == "" && local.storage_rg == "") ? 1 : 0
  name                        = local.default_storage_name
  resource_group_name         = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  location                    = local.default_location
  account_tier                = var.storage_tier
  account_replication_type    = var.storage_repl
}

# Aditional disk
# https://documentation.suse.com/external-tree/en-us/hana/4.0/suse-manager/administration/public-cloud-azure.html
resource "azurerm_managed_disk" "hana_extra_disk" {
  count                  = local.disks_number > 0 ? local.disks_number : 0
  name                   = "hana_disk_${local.disks_names[count.index]}"
  location               = local.default_location
  resource_group_name    = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  storage_account_type   = local.disks_type[count.index]
  create_option          = "Empty"
  disk_size_gb           = local.disks_size[count.index]
  depends_on             = [azurerm_linux_virtual_machine.my_vm]
}

resource "azurerm_virtual_machine_data_disk_attachment" "hana_extra_disk_attach" {  
  count              = local.disks_number > 0 ? local.disks_number : 0
  managed_disk_id    = azurerm_managed_disk.hana_extra_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.my_vm.id
  lun                = local.disks_luns[count.index]
  caching            = local.disks_caching[count.index]
}

# Create virtual machine for HANA
resource "azurerm_linux_virtual_machine" "my_vm" {
  name                            = var.vm_hana_name
  location                        = local.default_location
  resource_group_name             = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  network_interface_ids           = [azurerm_network_interface.my_network_interface_hana.id]
  size                            = var.vm_hana_size
  custom_data                     = data.template_cloudinit_config.config_hana.rendered
  computer_name                   = var.vm_hana_name
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = true

  os_disk {
    name                 = "hana_os_disk"
    caching              = "ReadWrite"
    storage_account_type = var.vm_hana_disk_type
  }

  source_image_reference {
    publisher = local.hana_publisher
    offer     = local.hana_offer
    sku       = local.hana_sku
    version   = local.hana_version
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  boot_diagnostics {
    storage_account_uri = tobool(var.vm_hana_boot_diag) == true ? (
      local.storage_account != "" ? data.azurerm_storage_account.my_storage_account[0].primary_blob_endpoint : azurerm_storage_account.my_storage_account[0].primary_blob_endpoint
      ) : null
  }
}
