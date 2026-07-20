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


###--------------------------------------
# Private Endpoint
#----------------------------------------
resource "azurerm_private_dns_zone" "kv_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.db_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "kv-dns-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.db_rg.name

  #  depends_on = [
  #  azurerm_subnet.db
  #]
}

resource "azurerm_private_endpoint" "vault_pe" {
  name                = "${azurerm_key_vault.kv.name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.db_rg.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azurerm_key_vault.kv.name}-psc"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"] # https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_dns.id]
  }
}
