###--------------------------
# Provider variables
#----------------------------
variable "rg_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Location"
  type        = string
  default     = "canadacentral"
}


###--------------------------
# VNet
#----------------------------
variable "vnet_cidrs" {
  description = "VNet CIDR"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "bastion_subnet_cidrs" {
  description = "Subnet CIDR for System Node Pool"
  type        = list(string)
  default     = ["10.0.1.0/26"]
}

variable "app_subnet_cidrs" {
  description = "Subnet CIDR for System Node Pool"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Subnet CIDR for System Node Pool"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}


###------------------------
# PostgreSQL Flexible
#--------------------------
variable "enable_initialization" {
  description = "When true, deploy VM to perform initialization and PostgreSQL extension installs."
  type        = bool
  default     = false
}

variable "psql_name" {
  description = "PostgreSQL server name."
  type        = string
}

variable "admin_username" {
  description = "PostgreSQL admin username (cannot be 'root' or 'admin')"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "PostgreSQL admin password."
  type        = string
  sensitive   = true
}

variable "psql_version" {
  description = "PostgreSQL version."
  type        = string

  validation {
    condition     = contains(["11", "12", "13", "14", "15", "16", "17", "18"], var.psql_version)
    error_message = "Accepted values are 11, 12, 13, 14, 15, 16, 17, or 18"
  }
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "storage_mb" {
  description = "DB storage size in MB."
  type        = number
  default     = 32768
}

variable "storage_tier" {
  description = "DB storage tier."
  type        = string
  default     = "P4"

  validation {
    condition     = contains(["P4", "P6", "P10", "P15", "P20", "P30", "P40", "P50", "P60", "P70", "P80"], var.storage_tier)
    error_message = "Accepted values are P4, P6, P10, P15, P20, P30, P40, P50, P60, P70, or P80"
  }
}

variable "sku_name" {
  description = "PostgreSQL server SKU."
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "allowed_extensions" {
  description = "Extensions allowlist (comma delimited)."
  type        = string
  default     = "UUID-OSSP"
}
