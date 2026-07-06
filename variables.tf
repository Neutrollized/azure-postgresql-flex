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

variable "pe_subnet_cidrs" {
  description = "Subnet CIDR for Private Endpoints"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "app_subnet_cidrs" {
  description = "Subnet CIDR for app"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Subnet CIDR for database"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}


###------------------------
# Azure Key Vault
#--------------------------
variable "network_acls_ip_rules" {
  description = "List of IPs allowed bypass the network ACLs. Add yours if you're running Terraform from a local machine"
  type        = list(string)
  default     = []
}


###------------------------
# PostgreSQL Flexible
#--------------------------
variable "enable_initialization" {
  description = "When true, deploy VM to perform initialization and PostgreSQL extension installs."
  type        = bool
  default     = true
}

variable "psql_name" {
  description = "PostgreSQL server name."
  type        = string
}

variable "zone" {
  description = "PostgreSQL server zone."
  type        = string
  default     = null
}

variable "admin_username" {
  description = "PostgreSQL admin username (cannot be 'root' or 'admin')"
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

variable "storage_mb" {
  description = "DB storage size in MB."
  type        = number
  default     = 32768

  validation {
    condition     = contains([32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4193280, 4194304, 8388608, 16777216, 33553408], var.storage_mb)
    error_message = "Accepted values are 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4193280, 4194304, 8388608, 16777216, or 33553408"
  }
}

variable "auto_grow_enabled" {
  description = "When true, enable storage autogrow feature."
  type        = bool
  default     = false
}

variable "sku_name" {
  description = "PostgreSQL server SKU. Follows the 'tier' + 'name' pattern."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "pgbouncer_enabled" {
  description = "Value of the pgboucner.enable config"
  type        = bool
  default     = false
}

variable "pgbouncer_settings" {
  description = "Map of PgBouncer settings."
  type        = map(string)
  default = {
    "pgbouncer.default_pool_size" = "50"
    "pgbouncer.max_client_conn"   = "5000"
    "pgbouncer.min_pool_size"     = "0"
  }
}

variable "allowed_extensions" {
  description = "Extensions allowlist (comma delimited)."
  type        = string
  default     = "UUID-OSSP"
}


###------------------------
# PostgreSQL Database
#--------------------------
variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "collation" {
  description = "Specifies the Collation for the database"
  type        = string
  default     = "en_US.utf8"
}

variable "charset" {
  description = "Specifies the Charset for the database"
  type        = string
  default     = "utf8"
}


###-----------------------
# Init VM
#-------------------------
variable "disable_password_authentication" {
  description = "When true, use SSH key auth. When false, use password auth."
  type        = bool
  default     = false
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for  the init VM admin user."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
