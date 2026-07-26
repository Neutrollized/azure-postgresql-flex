# Get the global First-Party Enterprise Applicaiton ID
# https://learn.microsoft.com/en-us/azure/databricks/admin/account-settings/
data "azuread_service_principal" "dbx_sp" {
  client_id = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
}

data "azurerm_key_vault" "psql_kv" {
  name                = var.psql_kv_name
  resource_group_name = var.psql_kv_rg_name
}

resource "azurerm_role_assignment" "dbx_kv_secrets_user" {
  scope                = data.azurerm_key_vault.psql_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azuread_service_principal.dbx_sp.object_id
}


resource "databricks_secret_scope" "psql_kv_scope" {
  name = "my-psql-flex-kv-scope"

  keyvault_metadata {
    resource_id = data.azurerm_key_vault.psql_kv.id
    dns_name    = data.azurerm_key_vault.psql_kv.vault_uri
  }

  depends_on = [
    azurerm_role_assignment.dbx_kv_secrets_user
  ]
}
