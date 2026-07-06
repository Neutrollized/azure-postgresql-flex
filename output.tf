output "_bastion_ssh_access" {
  value       = "via Azure Portal -> jumpbox VM -> Connect (left-hand nav panel) -> Bastion -> Provide credentials and SSH key to open new browser window to connect"
  description = "Connecting to Linux VM via Bastion"
}

output "_connect_to_postgres_flex_string" {
  value       = "psql 'host=${azurerm_postgresql_flexible_server.psql.fqdn} port=5432 dbname=${azurerm_postgresql_flexible_server_database.gis_db.name} user=${nonsensitive(data.azurerm_key_vault_secret.db_username.value)} password=${nonsensitive(data.azurerm_key_vault_secret.db_password.value)} sslmode=require'"
  description = "Connection from Linux VM to PostgreSQL Flex"
}
