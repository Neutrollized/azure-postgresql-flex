data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "db_rg" {
  name     = var.rg_name
  location = var.location
}


#---------------------------------------------
# Azure PostgreSQL Flex
#---------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                     = "my-psql-kv"
  resource_group_name      = azurerm_resource_group.db_rg.name
  location                 = var.location
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "Set", "Delete", "List", "Purge"]
  }
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "psql-admin-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "psql-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.kv.id
}


#---------------------------------------------
# Azure PostgreSQL Flex
#---------------------------------------------
data "azurerm_key_vault_secret" "db_username" {
  name         = "psql-admin-username"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_secret.db_username
  ]
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "psql-admin-password"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_secret.db_password
  ]
}


resource "azurerm_private_dns_zone" "psql" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.db_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "psql" {
  name                  = "psql-dns-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.psql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.db_rg.name

  depends_on = [
    azurerm_subnet.db
  ]
}

resource "azurerm_postgresql_flexible_server" "psql" {
  name                   = var.psql_name
  resource_group_name    = azurerm_resource_group.db_rg.name
  location               = var.location
  version                = var.psql_version
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.psql.id
  administrator_login    = data.azurerm_key_vault_secret.db_username.value
  administrator_password = data.azurerm_key_vault_secret.db_password.value
  #  administrator_login           = var.admin_username
  #administrator_password        = var.admin_password
  public_network_access_enabled = false
  zone                          = 1

  storage_mb   = var.storage_mb
  storage_tier = var.storage_tier # https://azure.microsoft.com/en-us/pricing/details/managed-disks/

  sku_name = var.sku_name

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.psql
  ]
}

resource "azurerm_postgresql_flexible_server_database" "gis_db" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.psql.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# allowlist extensions that can be installed
resource "azurerm_postgresql_flexible_server_configuration" "enable_exts" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.psql.id
  value     = var.allowed_extensions
}
