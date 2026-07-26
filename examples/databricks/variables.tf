variable "dbx_host" {
  description = "Azure Databricks Workspace name"
  type        = string
}

variable "psql_kv_name" {
  description = "Azure Key Vault name"
  type        = string
}

variable "psql_kv_rg_name" {
  description = "Azure Key Vault RG name"
  type        = string
}
