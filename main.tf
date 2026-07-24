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


resource "azurerm_postgresql_flexible_server" "psql" {
  name                          = var.psql_name
  resource_group_name           = azurerm_resource_group.db_rg.name
  location                      = var.location
  administrator_login           = data.azurerm_key_vault_secret.db_username.value
  administrator_password        = random_password.db_password.result
  public_network_access_enabled = false
  zone                          = var.zone

  version           = var.psql_version
  sku_name          = var.sku_name
  storage_mb        = var.storage_mb
  auto_grow_enabled = var.auto_grow_enabled

  dynamic "high_availability" {
    for_each = var.ha_enabled ? [1] : []
    content {
      mode = var.ha_mode
    }
  }

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

  depends_on = [
    azurerm_private_endpoint.psql_pe
  ]
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

  depends_on = [
    azurerm_private_endpoint.psql_pe
  ]
}


###--------------------------------------
# Private Endpoint
#----------------------------------------
resource "azurerm_private_dns_zone" "psql_dns" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.db_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "psql" {
  name                  = "psql-dns-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.psql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.db_rg.name

  #  depends_on = [
  #  azurerm_subnet.db
  #]
}

resource "azurerm_private_endpoint" "psql_pe" {
  name                = "${azurerm_postgresql_flexible_server.psql.name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.db_rg.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azurerm_postgresql_flexible_server.psql.name}-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.psql.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"] # https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource
  }

  private_dns_zone_group {
    name                 = "psql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.psql_dns.id]
  }
}
