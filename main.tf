data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "db_rg" {
  name     = var.rg_name
  location = var.location
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


#---------------------------------------------
# Azure PostgreSQL Flex
#---------------------------------------------
# using PostgreSQL Flexible server name as the AKV/secrets' prefix
resource "azurerm_key_vault" "kv" {
  name                     = "${var.psql_name}-akv"
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
  name         = "${var.psql_name}-admin-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault.kv
  ]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "${var.psql_name}-admin-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault.kv
  ]
}


#---------------------------------------------
# Azure PostgreSQL Flex
#---------------------------------------------
data "azurerm_key_vault_secret" "db_username" {
  name         = "${var.psql_name}-admin-username"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_secret.db_username
  ]
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "${var.psql_name}-admin-password"
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
  name                          = var.psql_name
  resource_group_name           = azurerm_resource_group.db_rg.name
  location                      = var.location
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.psql.id
  administrator_login           = data.azurerm_key_vault_secret.db_username.value
  administrator_password        = random_password.db_password.result
  public_network_access_enabled = false
  zone                          = var.zone

  version           = var.psql_version
  sku_name          = var.sku_name
  storage_mb        = var.storage_mb
  auto_grow_enabled = var.auto_grow_enabled

  lifecycle {
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.psql
  ]
}

resource "azurerm_postgresql_flexible_server_database" "gis_db" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.psql.id
  collation = "en_US.utf8"
  charset   = "utf8"

  # enable this to prevent accidental data loss
  #lifecycle {
  #  prevent_destroy = true
  #}
}

# allowlist extensions that can be installed
resource "azurerm_postgresql_flexible_server_configuration" "enable_exts" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.psql.id
  value     = var.allowed_extensions
}
