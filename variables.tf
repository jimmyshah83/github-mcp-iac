###############################
# Variables
###############################
variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the VNet."
  type        = string
}

variable "web_subnet_name" {
  description = "Name of the web subnet."
  type        = string
}

variable "web_subnet_prefix" {
  description = "Address prefix for the web subnet."
  type        = string
}

variable "db_subnet_name" {
  description = "Name of the database subnet."
  type        = string
}

variable "db_subnet_prefix" {
  description = "Address prefix for the database subnet."
  type        = string
}

variable "vmss_name" {
  description = "Name of the VM Scale Set."
  type        = string
}

variable "vm_size" {
  description = "Size of the VM instances."
  type        = string
}

variable "vmss_capacity_default" {
  description = "Default number of VMSS instances."
  type        = number
}

variable "admin_username" {
  description = "Admin username for VMSS."
  type        = string
}

variable "admin_password" {
  description = "Admin password for VMSS."
  type        = string
  sensitive   = true
}

variable "vm_image_publisher" {
  description = "Publisher for VM image."
  type        = string
}

variable "vm_image_offer" {
  description = "Offer for VM image."
  type        = string
}

variable "vm_image_sku" {
  description = "SKU for VM image."
  type        = string
}

variable "postgres_server_name" {
  description = "Name of the PostgreSQL server."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL version."
  type        = string
}

variable "postgres_admin_username" {
  description = "PostgreSQL admin username."
  type        = string
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password."
  type        = string
  sensitive   = true
}

variable "postgres_storage_mb" {
  description = "Storage size for PostgreSQL in MB."
  type        = number
}

variable "postgres_sku" {
  description = "SKU for PostgreSQL Flexible Server."
  type        = string
}

variable "postgres_ha_mode" {
  description = "High availability mode for PostgreSQL."
  type        = string
  default     = "ZoneRedundant"
}

variable "postgres_backup_retention_days" {
  description = "Backup retention days for PostgreSQL."
  type        = number
  default     = 7
}

variable "postgres_geo_backup" {
  description = "Enable geo-redundant backup for PostgreSQL."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 14
}

variable "dns_zone_name" {
  description = "DNS zone name for web servers."
  type        = string
}

variable "dns_record_name" {
  description = "DNS A record name for web servers."
  type        = string
}

variable "vm_backup_retention_days" {
  description = "Number of daily restore points for VM backups."
  type        = number
  default     = 14
}

variable "budget_amount" {
  description = "Monthly budget amount in local currency."
  type        = number
}

variable "budget_start_date" {
  description = "Start date for budget in YYYY-MM-DD format."
  type        = string
}

variable "alert_email" {
  description = "Email address for budget and autoscale alerts."
  type        = string
}

variable "cost_center" {
  description = "Cost center tag value."
  type        = string
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}
