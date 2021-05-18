variable "subscription_id" {
  description = "Subscriptions ID to be used."
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Client ID from Azure."
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Client secret from Azure."
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Tenant ID from Azure."
  type        = string
  default     = ""
}

variable "resource_group" {
  description = "Resource group name to create."
  type        = string
  default     = "hana-rg"
}

variable "location" {
  description = "Location where resources should be created."
  type        = string
  default     = "westus"
}

variable "admin_username" {
  description = "Name for the admin user."
  type        = string
  default     = "azureroot"
}

variable "admin_password" {
  description = "Password for admin user."
  type        = string
  default     = "Passw0rd123"
}

variable "vm_hana_image" {
  description = "Image for SUMA formatted as publisher:offer:sku:version."
  type        = string
  default     = "SUSE:manager-server-4-1-byos:gen1:latest"
}

variable "vm_hana_name" {
  description = "Name for instance and hostname of SUMA."
  type        = string
  default     = "hana"
}

variable "vm_hana_size" {
  description = "Size of virtual machine."
  type        = string
  default     = "Standard_A2m_v2"
}

variable "vm_hana_disk_type" {
  description = "Type of disk for SUMA OS disk."
  type        = string
  default     = "Standard_LRS"
}

variable "cloudinit_hana" {
  description = "Cloudinit file for SUMA."
  type        = string
  default     = "cloud.yaml"
}

variable "vm_hana_swap_size" {
  description = "Swap memory for SUMA."
  type        = number
  default     = 4096
}

variable "vm_hana_reg_code" {
  description = "SUSE registration code for SUMA."
  type        = string
  default     = "XXXXXXXXXXXXXXX"
}

variable "vm_hana_reg_email" {
  description = "SUSE registration email for SUMA."
  type        = string
  default     = "mail@example.com"
}

variable "vm_hana_net_accel" {
  description = "Enable acceleration flag in network interface."
  type        = string
  default     = "false"
}

variable "vnet_name" {
  description = "Name of virtual network for HANA."
  type        = string
  default     = "vnet"
}

variable "vnet_addr" {
  description = "Network address for virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  description = "Name of virtual subnet."
  type        = string
  default     = "subnet"
}

variable "subnet_addr" {
  description = "Network address Name of virtual subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "nsg_name" {
  description = "Network security group name."
  type        = string
  default     = ""
}

variable "nsg_rules" {
  description = "Network Security Group Rules."
  type        = map
  default  = { 
    name                       = ""
    direction                  = ""
    access                     = ""
    protocol                   = ""
    source_port_range          = ""
    destination_port_range     = ""
    source_address_prefix      = ""
    destination_address_prefix = ""
  }
}

variable "vm_hana_ip" {
  description = "IP Address for HANA."
  type        = string
  default     = "10.0.1.100"
}

variable "storage_account" {
  description = "Storage to use for HANA."
  type        = string
  default     = "storage:rg"
}

variable "storage_tier" {
  description = "Storage tier to create storage account."
  type        = string
  default     = "Standard"
}

variable "storage_repl" {
  description = "Storage replication type to create storage account."
  type        = string
  default     = "LRS"
}

variable "vm_hana_boot_diag" {
  description = "Enable or not boot diagnostics."
  type        = string
  default     = "true"
}

variable "vm_hana_pub_ip" {
  description = "Enable public IP for HANA."
  type        = string
  default     = "false"
}

variable "hana_disks" {
  description = "Disk layout for HANA."
  type        = map
  default  = { 
    disks_type       = ""
    disks_size       = ""
    caching          = ""
    writeaccelerator = ""
    luns             = ""
    names            = ""
    paths            = ""
  }
}

variable "hana_media_local" {
  description = "Path for mounting HANA media."
  type        = string
  default     = "/mnt/hanamedia"
}

variable "hana_media_storage" {
  description = "Path for HANA media in storage account."
  type        = string
  default     = "/hanamedia"
}

variable "hana_media_key" {
  description = "Key for accessing HANA media."
  type        = string
  default     = ""
}

variable "hana_media_add_fstab" {
  description = "Add HANA media entry to /etc/fstab file."
  type        = string
  default     = "false"
}

variable "hana_install_packages" {
  description = "Add SUSE packages for HANA in VM."
  type        = string
  default     = "true"
}

variable "hana_software_path" {
  description = "Full path to install SAP HANA extracted installation media."
  type        = string
  default     = "/mnt/hanamedia/hana"
}

variable "hana_monitoring_enabled" {
  description = "Define use of monitoring in the VMs."
  type        = string
  default     = "true"
}

variable "hana_sid" {
  description = "Define sid for HANA."
  type        = string
  default     = "hdb"
}

variable "hana_instance" {
  description = "Define instance for HANA."
  type        = string
  default     = "00"
}

variable "hana_password" {
  description = "Define password for HANA."
  type        = string
  default     = "Passw0rd123"
}

variable "hana_system_user_password" {
  description = "Define password for system use of HANA."
  type        = string
  default     = "Passw0rd123"
}

variable "hana_sapadm_password" {
  description = "Define password for sapadm of HANA."
  type        = string
  default     = "Passw0rd123"
}

variable "monit_exposition_port" {
  description = "Monitoring exposition port for monitoring HANA."
  type        = string
  default     = "9668"
}

variable "monit_multi_tenant" {
  description = "Support multi tenant for monitoring HANA."
  type        = string
  default     = "true"
}

variable "monit_user" {
  description = "User for monitoring HANA."
  type        = string
  default     = "SYSTEM"
}

variable "monit_port" {
  description = "Monitoring port for HANA."
  type        = string
  default     = "30013"
}

variable "monit_timeout" {
  description = "Monitoring timeout for HANA."
  type        = string
  default     = "600"
}
