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
  default     = "sap-rg"
}

variable "location" {
  description = "Location where resources should be created."
  type        = string
  default     = "brazilsouth"
}

variable "admin_username" {
  description = "Name for the admin user."
  type        = string
  default     = "azureroot"
}

variable "admin_password" {
  description = "Password for admin user."
  type        = string
  default     = "Passw0rd"
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

variable "sap_media_local" {
  description = "Path for mounting SAP media."
  type        = string
  default     = "/mnt/sapmedia"
}

variable "sap_media_storage" {
  description = "Path for SAP media in storage account."
  type        = string
  default     = "/sapmedia"
}

variable "sap_media_key" {
  description = "Key for accessing SAP media."
  type        = string
  default     = ""
}

variable "sap_media_add_fstab" {
  description = "Add SAP media entry to /etc/fstab file."
  type        = string
  default     = "false"
}

variable "add_pub_ip" {
  description = "Add public IP to SAP VM."
  type        = string
  default     = "false"
}

variable "add_boot_diag" {
  description = "Add boot diagnostics to SAP VM."
  type        = string
  default     = "true"
}

variable "machines" {
  description = "Machines for SAP environment."
  type        = map
  default  = { 
    vm_image       = ""
    vm_name        = ""
    vm_size        = ""
    vm_ip          = ""
    vm_disk_type   = ""
    vm_net_accel   = ""
    cloudinit      = ""
    vm_swap_size   = ""
    vm_reg_code    = ""
    vm_reg_email   = ""
    vm_mount_media = ""
  }
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

variable "lb_rules" {
  description = "Load Balancing Rules."
  type        = map
  default  = { 
    probe_name              = ""
    probe_port              = ""
    protocol                = ""
    frontend_port           = ""
    backend_port            = ""
    enable_floating_ip      = ""
    idle_timeout_in_minutes = ""
    load_distribution       = ""
  }
}

variable "create_lb" {
  description = "Set if load balancer should be created."
  type        = string
  default     = "true"
}

variable "create_lb_public_ip" {
  description = "Set if public IP should be attached to the load balancer."
  type        = string
  default     = "true"
}

variable "lb_private_ip" {
  description = "Set IP address for use in load balancer."
  type        = string
  default     = ""
}

variable "lb_sku" {
  description = "Set IP address for use in load balancer."
  type        = string
  default     = "Basic"
}

variable "create_fencing_app" {
  description = "Set if fencing application should be created."
  type        = string
  default     = "false"
}

variable "fencing_app_name" {
  description = "Set fencing application name."
  type        = string
  default     = "fencing_app"
}

variable "enable_monitoring" {
  description = "Set if monitoring should be enabled on nodes."
  type        = string
  default     = "false"
}

variable "cluster_install" {
  description = "Set if HA cluster should be installed."
  type        = string
  default     = "true"
}

variable "cluster_unicast" {
  description = "Set if unicast should be used in the cluster."
  type        = string
  default     = "true"
}

variable "cluster_password" {
  description = "Set password used for cluster user."
  type        = string
  default     = "Passw0rd"
}

variable "enable_netapp_files" {
  description = "Set if NetApp files should be enabled."
  type        = string
  default     = "false"
}

variable "netapp_account_name" {
  description = "Set NetApp account name for usage."
  type        = string
  default     = ""
}

variable "netapp_pool_name" {
  description = "Set NetApp pool name for usage."
  type        = string
  default     = ""
}

variable "netapp_pool_service_level" {
  description = "Set NetApp pool service level."
  type        = string
  default     = "Premium"
}

variable "netapp_pool_size" {
  description = "Set NetApp pool size in Terabytes."
  type        = number
  default     = 4
}

variable "netapp_volume_name" {
  description = "Set NetApp volume name."
  type        = string
  default     = ""
}

variable "netapp_volume_path" {
  description = "Set NetApp volume path."
  type        = string
  default     = ""
}

variable "netapp_volume_service_level" {
  description = "Set NetApp volume service level."
  type        = string
  default     = "Premium"
}

###################
# SAP
###################

variable "sap_ascs_instance_sid" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ascs_instance_id" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ascs_root_user" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ascs_root_password" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ascs_vip_address" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ascs_vip_hostname" {
  description = "Set password used for cluster user."
  type        = string
}

# ERS
variable "sap_ers_instance_sid" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ers_instance_id" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ers_root_user" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ers_root_password" {
  description = "Set password used for cluster user."
  type        = string
}

variable "sap_ers_vip_address" {
  description = "Set password used for cluster user."
  type        = string
}
variable "sap_ers_vip_hostname" {
  description = "Set password used for cluster user."
  type        = string
}

# MISC
variable "sid_adm_password" {
  description = "Password for sidadmn"
  type        = string
}

variable "sap_adm_password" {
  description = "Password for sidadm user"
  type        = string
}

variable "master_password" {
  description = "Password for sapadm user"
  type        = string
}

variable "sapmnt_path" {
  description = "SAP profile path after installation"
  type        = string
  default     = "/sapmnt"
}
sapmnt_path = "/sapmnt"
variable "sidadm_user_uid" {
  description = "UID for SAP instance (ASCS/ERS)"
  type        = string
}

variable "sidadm_user_gid" {
  description = "GUID for SAP instance (ASCS/ERS)"
  type        = string
}
sidadm_user_gid = "sapmnt_inst_media"
variable "sapmnt_inst_media" {
  description = "Path for NW media folder"
  type        = string
}

variable "swpm_folder" {
  description = "Path for SWPM installation"
  type        = string
}
swpm_folder = "/mnt/sapmedia/swpm_/"
variable "sapexe_folder" {
  description = "Path for SAP kernel installation"
  type        = string
}

variable "additional_dvds" {
  description = "Path for additional DVDs"
  type        = string
}

# HANA
variable "sap_hana_host" {
  description = "SAP HANA host"
  type        = string
}
variable "sap_hana_ip" {
  description = "SAP HANA host"
  type        = string
}
variable "sap_hana_sid" {
  description = "SAP HANA sid"
  type        = string
}
variable "sap_hana_instance" {
  description = "SAP HANA instance"
  type        = string
}
variable "sap_hana_password" {
  description = "SAP HANA password"
  type        = string
}
