output "_bastion_connection_string" {
  value       = "az network bastion ssh --name ${azurerm_bastion_host.bastion.name} --resource-group ${azurerm_resource_group.db_rg.name} --target-resource-id ${azurerm_linux_virtual_machine.jumpbox.id} --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa"
  description = "Connection to Linux VM via Azure Bastion"
}

output "_connect_to_postgres_flex_string" {
  value       = "psql 'host=${azurerm_postgresql_flexible_server.psql.fqdn} port=5432 dbname=${azurerm_postgresql_flexible_server_database.gis_db.name} user=${nonsensitive(data.azurerm_key_vault_secret.db_username.value)} password=${nonsensitive(data.azurerm_key_vault_secret.db_password.value)} sslmode=require'"
  description = "Connection from Linux VM to PostgreSQL Flex"
}

# for troubleshooting cloud-init
#output "_init_connection_string" {
#  value = "az network bastion ssh --name ${azurerm_bastion_host.bastion.name} --resource-group ${azurerm_resource_group.db_rg.name} --target-resource-id ${azurerm_linux_virtual_machine.psql_init[0].id} --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa"
#}
