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
  default_rg_name      = var.resource_group != "" ? var.resource_group : "sap-rg"
  default_location     = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].location : var.location
  default_vnet_name    = var.vnet_name != "" ? var.vnet_name : "vnet"
  default_subnet_name  = var.subnet_name != "" ? var.subnet_name : "subnet"

  # Storage account
  storage_data         = split(":", var.storage_account)
  storage_account      = local.storage_data[0]
  storage_rg           = local.storage_data[1]
  default_storage_name = local.storage_account != "" ? local.storage_account : "diag${random_id.randomId.hex}"

  # SAP VMs
  vm_number      = length(var.machines["vm_image"]) == 0 ? 0 : length(split(",", var.machines["vm_image"]))
  vm_image       = local.vm_number > 0 ? ([for image in split(",", var.machines["vm_image"]) : trimspace(image)]) : null
  vm_name        = local.vm_number > 0 ? ([for name in split(",", var.machines["vm_name"]) : trimspace(name)]) : null
  vm_size        = local.vm_number > 0 ? ([for vm_size in split(",", var.machines["vm_size"]) : trimspace(vm_size)]) : null
  vm_ip          = local.vm_number > 0 ? ([for ip in split(",", var.machines["vm_ip"]) : trimspace(ip)]) : null
  vm_disk_type   = local.vm_number > 0 ? ([for disk_type in split(",", var.machines["vm_disk_type"]) : trimspace(disk_type)]) : null
  vm_net_accel   = local.vm_number > 0 ? ([for net_accel in split(",", var.machines["vm_net_accel"]) : trimspace(net_accel)]) : null
  vm_cloudinit   = local.vm_number > 0 ? ([for cloudinit in split(",", var.machines["cloudinit"]) : trimspace(cloudinit)]) : null
  vm_swap_size   = local.vm_number > 0 ? ([for swap_size in split(",", var.machines["vm_swap_size"]) : tonumber(trimspace(swap_size))]) : null
  vm_reg_code    = local.vm_number > 0 ? ([for reg_code in split(",", var.machines["vm_reg_code"]) : trimspace(reg_code)]) : null
  vm_reg_email   = local.vm_number > 0 ? ([for reg_email in split(",", var.machines["vm_reg_email"]) : trimspace(reg_email)]) : null
  vm_mount_media = local.vm_number > 0 ? ([for mount_media in split(",", var.machines["vm_mount_media"]) : tobool(trimspace(mount_media))]) : null

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
  nsg_priority_base              = 1000

  # LB Rules
  lb_rules_size                    = length(var.lb_rules["probe_name"]) > 0 ? length(split(",", var.lb_rules["probe_name"])) : 0
  lb_rules_probe_name              = local.lb_rules_size > 0 ? ([for probe_name in split(",", var.lb_rules["probe_name"]) : trimspace(probe_name)]) : null
  lb_rules_probe_port              = local.lb_rules_size > 0 ? ([for probe_port in split(",", var.lb_rules["probe_port"]) : trimspace(probe_port)]) : null
  lb_rules_protocol                = local.lb_rules_size > 0 ? ([for protocol in split(",", var.lb_rules["protocol"]) : trimspace(protocol)]) : null
  lb_rules_frontend_port           = local.lb_rules_size > 0 ? ([for frontend_port in split(",", var.lb_rules["frontend_port"]) : trimspace(frontend_port)]) : null
  lb_rules_backend_port            = local.lb_rules_size > 0 ? ([for backend_port in split(",", var.lb_rules["backend_port"]) : trimspace(backend_port)]) : null
  lb_rules_enable_floating_ip      = local.lb_rules_size > 0 ? ([for enable_floating_ip in split(",", var.lb_rules["enable_floating_ip"]) : tobool(trimspace(enable_floating_ip))]) : null
  lb_rules_idle_timeout_in_minutes = local.lb_rules_size > 0 ? ([for idle_timeout_in_minutes in split(",", var.lb_rules["idle_timeout_in_minutes"]) : tonumber(trimspace(idle_timeout_in_minutes))]) : null
  lb_rules_load_distribution       = local.lb_rules_size > 0 ? ([for load_distribution in split(",", var.lb_rules["load_distribution"]) : trimspace(load_distribution)]) : null

  # NetApp Files
  enable_netapp_files              = tobool(trimspace(var.enable_netapp_files))
}

# Set cloud-init file to run
data  "template_file" "config_sap" {
  count    = local.vm_number > 0 ? local.vm_number : 0
  template = file(local.vm_cloudinit[count.index])

  vars = {
    vm_number           = local.vm_number
    vm_name             = local.vm_name[count.index]
    vm_names            = replace(var.machines["vm_name"], ",", " ")
    vm_ip               = local.vm_ip[count.index]
    vm_ips              = replace(var.machines["vm_ip"], ",", " ")
    vm_ip_network       = cidrhost(var.subnet_addr, 0)
    vm_swap_size        = local.vm_swap_size[count.index]
    vm_reg_code         = local.vm_reg_code[count.index]
    vm_reg_email        = local.vm_reg_email[count.index]
    vm_mount_media      = local.vm_mount_media[count.index]
    admin_password      = var.admin_password
    storage_account     = local.storage_account
    sap_media_local     = var.sap_media_local
    sap_media_storage   = var.sap_media_storage
    sap_media_key       = var.sap_media_key
    sap_media_add_fstab = var.sap_media_add_fstab
    lb_private_ip       = var.lb_private_ip
    enable_monitoring   = var.enable_monitoring
    cluster_unicast     = var.cluster_unicast
    cluster_password    = var.cluster_password
    subscription_id     = data.azurerm_subscription.current.subscription_id
    resource_group      = local.default_rg_name
    tenant_id           = data.azurerm_subscription.current.tenant_id
    login_id            = tobool(var.create_fencing_app) == true ? azuread_application.azuread_app[0].application_id : data.azuread_application.azuread_app[0].application_id
    app_password        = tobool(var.create_fencing_app) == true ? azuread_application_password.azuread_app_password[0].value : "NONE"
    sap_instance_name   = var.sap_instance_name
    sap_ascs_instance_sid = var.sap_ascs_instance_sid
    sap_ascs_instance_id = var.sap_ascs_instance_id
    sap_ascs_root_user = var.sap_ascs_root_user
    sap_ascs_root_password = var.sap_ascs_root_password
    sap_ascs_vip_address = var.sap_ascs_vip_address
    sap_ascs_vip_hostname = var.sap_ascs_vip_hostname
    sap_ers_instance_sid = var.sap_ers_instance_sid
    sap_ers_instance_id = var.sap_ers_instance_id
    sap_ers_root_user = var.sap_ers_root_user
    sap_ers_root_password = var.sap_ers_root_password
    sap_ers_vip_address = var.sap_ers_vip_address
    sap_ers_vip_hostname = var.sap_ers_vip_hostname
    sid_adm_password = var.sid_adm_password
    sap_adm_password = var.sap_adm_password
    master_password = var.master_password
    sapmnt_path = var.sapmnt_path
    sidadm_user_uid = var.sidadm_user_uid
    sidadm_user_gid = var.sidadm_user_gid
    sapmnt_inst_media = var.sapmnt_inst_media
    swpm_folder = var.swpm_folder
    sapexe_folder = var.sapexe_folder
    additional_dvds = var.additional_dvds
    sap_hana_host = var.sap_hana_host
    sap_hana_ip = var.sap_hana_ip
    sap_hana_sid  = var.sap_hana_sid 
    sap_hana_instance = var.sap_hana_instance
    sap_hana_password = var.sap_hana_password
  }
}

data "template_cloudinit_config" "config_sap" {
  count         = local.vm_number > 0 ? local.vm_number : 0
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.config_sap[count.index].rendered
  }
}

# AzureAD Application
data "azuread_application" "azuread_app" {
  count        = tobool(var.create_fencing_app) == false ? 1 : 0
  display_name = var.fencing_app_name
}

resource "azuread_application" "azuread_app" {
  count                      = tobool(var.create_fencing_app) == true ? 1 : 0
  display_name               = var.fencing_app_name
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = false
  public_client              = false

  app_role {
    allowed_member_types = [
      "User",
      "Application",
    ]

    description  = "Admins can manage roles and perform all task actions"
    display_name = "Admin"
    value        = "Admin"
    is_enabled   = true
  }

  oauth2_permissions {
    admin_consent_description  = "Allow the application to fence SAP VMs on behalf of the signed-in user."
    admin_consent_display_name = var.fencing_app_name
    is_enabled                 = true
    type                       = "User"
    user_consent_description   = "Allow the application to fence SAP VMs on your behalf."
    user_consent_display_name  = var.fencing_app_name
    value                      = "user_impersonation"
  }
}

data "azuread_service_principal" "azuread_service_principal" {
  count                        = tobool(var.create_fencing_app) == false ? 1 : 0
  application_id               = data.azuread_application.azuread_app[0].application_id
}

resource "azuread_service_principal" "azuread_service_principal" {
  count                        = tobool(var.create_fencing_app) == true ? 1 : 0
  application_id               = azuread_application.azuread_app[0].application_id
  app_role_assignment_required = false
}

resource "random_password" "azuread_rnd_password" {
  count   = tobool(var.create_fencing_app) == true ? 1 : 0
  length  = 42
  special = false

  keepers = {
      resource_group = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  }
}

# Create random password for AzureAD Application
resource "azuread_application_password" "azuread_app_password" {
  count                 = tobool(var.create_fencing_app) == true ? 1 : 0
  application_object_id = azuread_application.azuread_app[0].id
  description           = var.fencing_app_name
  value                 = random_password.azuread_rnd_password[0].result
  end_date              = "2099-01-01T01:01:01Z"
}

# Create role definition for AzureAD Application
resource "azurerm_role_definition" "sap_role_fencing" {
  count             = tobool(var.create_fencing_app) == true ? 1 : 0
  name              = "sap_role_fencing"
  scope             = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].id : azurerm_resource_group.my_resource_group[0].id
  description       = "This role allows AzureAD Application to fence SAP VMs in Azure"
  assignable_scopes = [var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].id : azurerm_resource_group.my_resource_group[0].id]

  permissions {
    actions     = ["Microsoft.Compute/*/read",
                   "Microsoft.Compute/virtualMachines/powerOff/action",
                   "Microsoft.Compute/virtualMachines/start/action",
                   "Microsoft.Compute/virtualMachines/restart/action"]
    not_actions = []

  }
}

# Set permissions for the AzureAD Application in the VMs
resource "azurerm_role_assignment" "role_assign_sap_fencing" {
  count              = tobool(var.create_fencing_app) == true ? local.vm_number : 0
  # Scope based on resource group permission
  #scope              = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].id : azurerm_resource_group.my_resource_group[0].id
  # Scope based on virtual machines only
  scope              = azurerm_linux_virtual_machine.sap_vm[count.index].id
  role_definition_id = azurerm_role_definition.sap_role_fencing[0].role_definition_resource_id
  principal_id       = tobool(var.create_fencing_app) == true ? azuread_service_principal.azuread_service_principal[0].object_id : data.azuread_service_principal.azuread_service_principal[0].object_id
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

# Create public IPs for SAP VMs
resource "azurerm_public_ip" "my_public_ip" {
  count               = local.vm_number > 0 && tobool(var.add_pub_ip) == true ? local.vm_number : 0
  name                = "${local.vm_name[count.index]}_public_ip_${count.index}"
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  allocation_method   = "Dynamic"
}

# Create public IPs for Load Balancer
resource "azurerm_public_ip" "my_lb_public_ip" {
  count               = (tobool(var.create_lb) == true && tobool(var.create_lb_public_ip) == true) ? 1 : 0
  name                = "my_lb_public_ip"
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  allocation_method   = "Dynamic"
}

# Create load balancer
resource "azurerm_lb" "my_lb" {
  count               = tobool(var.create_lb) == true ? 1 : 0
  name                = "lb_sap"
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  sku                 = var.lb_sku

  frontend_ip_configuration {
    name                          = "my_lb_frontend_config"
    subnet_id                     = (tobool(var.create_lb) == true && tobool(var.create_lb_public_ip) == true) ? null : (var.subnet_name != "" ? data.azurerm_subnet.my_subnet[0].id : azurerm_subnet.my_subnet[0].id)
    private_ip_address_allocation = (tobool(var.create_lb) == true && tobool(var.create_lb_public_ip) == true) ? null : (var.lb_private_ip == "" ? "Dynamic" : "Static")
    private_ip_address            = (tobool(var.create_lb) == true && tobool(var.create_lb_public_ip) == true) ? null : (var.lb_private_ip == "" ? null : var.lb_private_ip)
    public_ip_address_id          = tobool(var.create_lb_public_ip) == true ? azurerm_public_ip.my_lb_public_ip[0].id : null
  }
}

# Create load balancer backend address pool
resource "azurerm_lb_backend_address_pool" "my_lb_bap" {
  count           = tobool(var.create_lb) == true ? 1 : 0
  name            = "lb_backend_address_pool"
  loadbalancer_id = azurerm_lb.my_lb[0].id
}

resource "azurerm_network_interface_backend_address_pool_association" "my_lb_network_interface" {
  count                   = (tobool(var.create_lb) == true && local.vm_number > 0) ? local.vm_number : 0
  ip_configuration_name   = "nic_configuration_${count.index}"
  network_interface_id    = azurerm_network_interface.my_network_interface_sap[count.index].id
  backend_address_pool_id = azurerm_lb_backend_address_pool.my_lb_bap[0].id
}

# Load balance probe rules
resource "azurerm_lb_probe" "my_lb_probe" {
  count               = tobool(var.create_lb) == true ? local.lb_rules_size : 0
  name                = "lb_probe_${count.index + 1}"
  port                = local.lb_rules_probe_port[count.index]
  interval_in_seconds = 5
  loadbalancer_id     = azurerm_lb.my_lb[0].id
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
}

# Load balance rules
resource "azurerm_lb_rule" "my_lb_rule" {
  count                          = tobool(var.create_lb) == true ? local.lb_rules_size : 0
  loadbalancer_id                = azurerm_lb.my_lb[0].id
  name                           = "lb_rule_${count.index + 1}"
  protocol                       = local.lb_rules_protocol[count.index]
  frontend_port                  = local.lb_rules_frontend_port[count.index]
  backend_port                   = local.lb_rules_backend_port[count.index]
  enable_floating_ip             = local.lb_rules_enable_floating_ip[count.index]
  idle_timeout_in_minutes        = local.lb_rules_idle_timeout_in_minutes[count.index]
  load_distribution              = local.lb_rules_load_distribution[count.index]
  enable_tcp_reset               = lower(var.lb_sku) == "basic" ? false : true
  frontend_ip_configuration_name = azurerm_lb.my_lb[0].frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.my_lb_bap[0].id
  probe_id                       = azurerm_lb_probe.my_lb_probe[count.index].id
  resource_group_name            = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
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

# Create network interface for SAP
resource "azurerm_network_interface" "my_network_interface_sap" {
  count                         = local.vm_number > 0 ? local.vm_number : 0
  name                          = "${local.vm_name[count.index]}_nic_${count.index}"
  location                      = local.default_location
  resource_group_name           = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  enable_accelerated_networking = local.vm_net_accel[count.index]

  ip_configuration {
    name                          = "nic_configuration_${count.index}"
    subnet_id                     = var.subnet_name != "" ? data.azurerm_subnet.my_subnet[0].id : azurerm_subnet.my_subnet[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.vm_ip[count.index]
    public_ip_address_id          = tobool(var.add_pub_ip) == true ? azurerm_public_ip.my_public_ip[count.index].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "my_network_nsg_association_sap" {
  count                     = local.vm_number > 0 ? local.vm_number : 0
  network_interface_id      = azurerm_network_interface.my_network_interface_sap[count.index].id
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
  count                    = (local.vm_number > 0 && tobool(var.add_boot_diag) == true && local.storage_account == "" && local.storage_rg == "") ? 1 : 0
  name                     = local.default_storage_name
  resource_group_name      = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  location                 = local.default_location
  account_tier             = var.storage_tier
  account_replication_type = var.storage_repl
}

resource "azurerm_proximity_placement_group" "proximity_pg" {
  name                = "sap_proximity_pg"
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
}

resource "azurerm_availability_set" "avail_set" {
  name                         = "sap_availability_set"
  location                     = local.default_location
  resource_group_name          = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  proximity_placement_group_id = azurerm_proximity_placement_group.proximity_pg.id
}

# NetApp Files

resource "azurerm_netapp_account" "account" {
  count               = local.enable_netapp_files == true ? 1 : 0
  name                = var.netapp_account_name
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  location            = local.default_location
}

resource "azurerm_netapp_pool" "pool" {
  count               = local.enable_netapp_files == true ? 1 : 0
  name                = var.netapp_pool_name
  account_name        = azurerm_netapp_account.account[0].name
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  service_level       = var.netapp_pool_service_level
  size_in_tb          = tonumber(var.netapp_pool_size)
}

resource "azurerm_netapp_volume" "volume" {
  count               = local.enable_netapp_files == true ? 1 : 0
  name                = var.netapp_volume_name
  location            = local.default_location
  resource_group_name = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  account_name        = azurerm_netapp_account.account[0].name
  pool_name           = azurerm_netapp_pool.pool[0].name
  volume_path         = var.netapp_volume_path
  service_level       = var.netapp_volume_service_level
  subnet_id           = var.subnet_name != "" ? data.azurerm_subnet.my_subnet[0].id : azurerm_subnet.my_subnet[0].id
  protocols           = ["NFSv4.1"]
  storage_quota_in_gb = 500

  lifecycle {
    prevent_destroy = true
  }
}

# Create virtual machines for SAP
resource "azurerm_linux_virtual_machine" "sap_vm" {
  count                           = local.vm_number > 0 ? local.vm_number : 0
  name                            = local.vm_name[count.index]
  location                        = local.default_location
  resource_group_name             = var.resource_group != "" ? data.azurerm_resource_group.my_resource_group[0].name : azurerm_resource_group.my_resource_group[0].name
  network_interface_ids           = [azurerm_network_interface.my_network_interface_sap[count.index].id]
  size                            = local.vm_size[count.index]
  custom_data                     = data.template_cloudinit_config.config_sap[count.index].rendered
  computer_name                   = local.vm_name[count.index]
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  availability_set_id             = azurerm_availability_set.avail_set.id
  proximity_placement_group_id    = azurerm_proximity_placement_group.proximity_pg.id

  os_disk {
    name                 = "sap_${local.vm_name[count.index]}_os_disk"
    caching              = "ReadWrite"
    storage_account_type = local.vm_disk_type[count.index]
  }

  source_image_reference {
    publisher = split(":", local.vm_image[count.index])[0]
    offer     = split(":", local.vm_image[count.index])[1]
    sku       = split(":", local.vm_image[count.index])[2]
    version   = split(":", local.vm_image[count.index])[3]
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  boot_diagnostics {
    storage_account_uri = tobool(var.add_boot_diag) == true ? (
      local.storage_account != "" ? data.azurerm_storage_account.my_storage_account[0].primary_blob_endpoint : azurerm_storage_account.my_storage_account[0].primary_blob_endpoint
      ) : null
  }
}
