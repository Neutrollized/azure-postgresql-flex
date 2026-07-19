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
# Azure Key Vault
#---------------------------------------------
# using PostgreSQL Flexible server name as the AKV/secrets' prefix
resource "azurerm_key_vault" "kv" {
  name                     = "${var.psql_name}-akv"
  resource_group_name      = azurerm_resource_group.db_rg.name
  location                 = var.location
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = false

  rbac_authorization_enabled = true

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.network_acls_ip_rules
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
}

# gives Terraform permission to manage secrets,
# otherwise you get RBAC error during secret creation step
resource "azurerm_role_assignment" "terraform_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# wait for Azure RBAC propagation
resource "time_sleep" "wait_for_rbac" {
  depends_on = [azurerm_role_assignment.terraform_secrets_officer]

  create_duration = "30s"
}


resource "azurerm_key_vault_secret" "db_username" {
  name         = "${var.psql_name}-admin-username"
  value        = var.admin_username
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    time_sleep.wait_for_rbac
  ]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "${var.psql_name}-admin-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    time_sleep.wait_for_rbac
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
  name                = "privatelink.postgres.database.azure.com"
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
      tags,
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
  collation = var.collation
  charset   = var.charset

  # enable this to prevent accidental data loss
  #lifecycle {
  #  prevent_destroy = true
  #}
}

# PgBouncer requires a non-burstable machine type, so I want to exclude this entire resource
# and not just set it to "false" (because it will still complain)
resource "azurerm_postgresql_flexible_server_configuration" "enable_pgbouncer" {
  count     = var.pgbouncer_enabled ? 1 : 0
  name      = "pgbouncer.enabled"
  server_id = azurerm_postgresql_flexible_server.psql.id
  value     = "true"
}

resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer_settings" {
  for_each  = var.pgbouncer_enabled ? var.pgbouncer_settings : {}
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.psql.id
  value     = each.value

  depends_on = [
    azurerm_postgresql_flexible_server_configuration.enable_pgbouncer
  ]
}

# allowlist extensions that can be installed
resource "azurerm_postgresql_flexible_server_configuration" "enable_exts" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.psql.id
  value     = var.allowed_extensions
}
