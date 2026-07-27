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
variable "network_cidrs" {
  description = "CIDR ranges used throughout the VNet (vnet, pe, app, db)."
  type = object({
    vnet = optional(list(string), ["10.1.0.0/16"])
    pe   = optional(list(string), ["10.1.1.0/24"])
    app  = optional(list(string), ["10.1.2.0/24"])
    db   = optional(list(string), ["10.1.3.0/24"])
  })
  default = {}
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

variable "ha_enabled" {
  description = "When true, enable high availability."
  type        = bool
  default     = false
}

variable "ha_mode" {
  description = "Sets high availability mode."
  type        = string
  default     = "ZoneRedundant"

  validation {
    condition     = contains(["SameZone", "ZoneRedundant"], var.ha_mode)
    error_message = "Accepted values are SameZone or ZoneRedundant"
  }
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


###-----------------------
# SQL commands vars
#-------------------------
variable "sql_schema_names" {
  description = "List of schemas to create in the database"
  type        = list(string)
  default     = []

  #default = ["staging", "core", "reporting"]
}

variable "sql_roles" {
  description = "Map of roles to create: role name => whether it's LOGIN and needs a password"
  type = map(object({
    login    = bool
    password = optional(string) # name of Key Vault secret holding the password, if login = true
  }))
  default = {}

  #default = {
  #  user01 = { login = false }
  #  user02 = { login = false }
  #  user03 = { login = true, password = "myPa55w0rd" }
  #}
}

variable "sql_user_role_grants" {
  description = "Map of role => { schemas => [...], privileges => [...] }"
  type = list(object({
    role = string
    user = string
  }))
  default = []

  #default = [
  #  { role = "postgresuser", user = "geoserver_db_user" }
  #]
}

variable "sql_db_conn_grants" {
  description = "List of databases to revoke default PUBLIC connect/temporary permissions from"
  type = map(object({
    connect_roles   = list(string)
    temporary_roles = list(string)
  }))
  default = {}

  #default = {
  #  my_db = {
  #    connect_roles   = ["loader_role", "publisher_role", "geoserver_role", "geoserver_db_user"]
  #    temporary_roles = ["loader_role", "publisher_role"]
  #  }
  #}
}

variable "sql_schema_privileges" {
  description = "Nested map structuring privileges by Role -> Schema -> Privileges"
  type = map(map(object({
    schema_privileges   = list(string) # e.g., ["USAGE", "CREATE"]
    table_privileges    = list(string) # e.g., ["SELECT", "INSERT"]
    sequence_privileges = list(string) # e.g., ["USAGE", "SELECT"]
  })))
  default = {}

  #default = {
  #  reporting_user = {
  #    core = {
  #      schema_privileges   = ["USAGE"]
  #      table_privileges    = ["SELECT"]
  #      sequence_privileges = ["USAGE"]
  #    }
  #    analytics = {
  #      schema_privileges   = ["USAGE"]
  #      table_privileges    = ["SELECT"]
  #      sequence_privileges = ["USAGE"]
  #    }
  #  }
  #  app_user = {
  #    core = {
  #      schema_privileges   = ["USAGE", "CREATE"]
  #      table_privileges    = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  #      sequence_privileges = ["USAGE", "SELECT", "UPDATE"]
  #    }
  #  }
  #}
}

variable "sql_default_schema_privileges" {
  description = "Nested map structuring privileges by Role -> Schema -> Privileges"
  type = map(map(object({
    table_privileges    = list(string) # e.g., ["SELECT", "INSERT"]
    sequence_privileges = list(string) # e.g., ["USAGE", "SELECT"]
    grantee_roles       = list(string) # ensures newly created tables are accessible
  })))
  default = {}

  #default = {
  #  reporting_user = {
  #    core = {
  #      table_privileges    = ["SELECT"]
  #      sequence_privileges = ["USAGE"]
  #      grantee_roles       = ["app_user"]
  #    }
  #    analytics = {
  #      table_privileges    = ["SELECT"]
  #      sequence_privileges = ["USAGE"]
  #      grantee_roles       = ["app_user","reporting_user"]
  #    }
  #  }
  #}
}

variable "sql_database_tables" {
  description = "Detailed blueprint of tables including fields, constraints, grants, and indexes"
  type = map(object({
    schema = string
    fields = list(object({
      name               = string
      type               = string
      null               = optional(bool, true)
      default_value      = optional(string)
      inline_constraints = optional(list(string), [])
    }))
    primary_keys = list(string)
    constraints  = optional(list(string), [])
    grants       = map(list(string))

    # --- Added for Indexes ---
    indexes = optional(list(object({
      name    = string
      columns = list(string)
      unique  = optional(bool, false)
      type    = optional(string, "btree") # btree, gin, gist, hash, etc.
    })), [])
  }))
  default = {}

  #default = {
  #  user_profiles = {
  #    schema       = "core"
  #    fields = [
  #      { name = "profile_id", type = "SERIAL", null = false },
  #      { name = "user_id", type = "INTEGER", null = false },
  #      { name = "email", type = "VARCHAR(255)", null = false },
  #      { name = "metadata", type = "JSONB", null = true }
  #    ]
  #    primary_keys = ["profile_id"]
  #    constraints = [
  #      "CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES core.users(id)"
  #    ]
  #    grants = {
  #      app_user = ["SELECT", "INSERT", "UPDATE"]
  #    }
  #    indexes = [
  #      {
  #        name    = "idx_user_profiles_email_lower"
  #        columns = ["LOWER(email)"] # Supports expression indexes!
  #        unique  = true
  #      },
  #      {
  #       name    = "idx_user_profiles_metadata"
  #        columns = ["metadata"]
  #        type    = "gin" # Perfect for JSONB columns
  #      }
  #     ]
  #  }
  #}
}

variable "sql_triggers" {
  description = "A map of tables that require an automated updated_at timestamp trigger"
  type = map(object({
    schema = string
    table  = string
  }))
  default = {}

  #default = {
  #  pub_registry_trigger = {
  #    schema = "platform_metadata"
  #    table  = "publication_registry"
  #  }
  #  user_accounts_trigger = {
  #    schema = "core"
  #    table  = "user_accounts"
  #  }
  #}
}
