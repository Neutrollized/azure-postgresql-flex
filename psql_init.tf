# splits comma-delimited string list of extensions in uppercase into an actual list in lowercase
# i.e. "POSTGIS, POSTGIS_RASTER" -> ["postgis", "postgis_raster"]
locals {
  allowed_extensions_list = [for ext in split(",", var.allowed_extensions) : trimspace(lower(ext))]
}


# NOTE: I'm not outputting this password anywhere becuase it's meant for an ephemeral VM
#       I'm only generating this because I need to provide a password
resource "random_password" "init_vm_password" {
  length           = 8
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_linux_virtual_machine" "psql_init" {
  count               = var.enable_initialization ? 1 : 0
  name                = "${var.psql_name}-init-vm"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location
  size                = "Standard_B1s" # cheapest, fine for a jump box
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.psql_init[count.index].id]

  disable_password_authentication = var.disable_password_authentication
  admin_password                  = var.disable_password_authentication ? null : random_password.init_vm_password.result

  dynamic "admin_ssh_key" {
    for_each = var.disable_password_authentication ? [1] : []
    content {
      username   = "azureuser"
      public_key = file(var.ssh_public_key_path)
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/psql_init.sh", {
    db_host                = azurerm_postgresql_flexible_server.psql.fqdn
    db_name                = azurerm_postgresql_flexible_server_database.gis_db.name
    akv_name               = azurerm_key_vault.kv.name
    akv_secret_db_username = azurerm_key_vault_secret.db_username.name
    akv_secret_db_password = azurerm_key_vault_secret.db_password.name
    allowed_extensions     = local.allowed_extensions_list
  }))

  depends_on = [
    azurerm_postgresql_flexible_server_configuration.enable_exts,
    azurerm_postgresql_flexible_server_database.gis_db,
  ]
}

resource "azurerm_network_interface" "psql_init" {
  count               = var.enable_initialization ? 1 : 0
  name                = "${var.psql_name}-init-nic"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_key_vault_access_policy" "vm_identity" {
  count        = var.enable_initialization ? 1 : 0
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.psql_init[count.index].identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

# cleanup psql init vm
resource "null_resource" "destroy_init_vm" {
  count = var.enable_initialization ? 1 : 0

  triggers = {
    always_run = timestamp()
  }

  # simple, static sleep timer
  #provisioner "local-exec" {
  #  command = "sleep 480 && az vm delete --yes --resource-group ${azurerm_resource_group.db_rg.name} --name ${var.psql_name}-init-vm"
  #}

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      for i in $(seq 1 16); do
        STATUS=$(az vm run-command invoke \
          --resource-group ${azurerm_resource_group.db_rg.name} \
          --name ${var.psql_name}-init-vm \
          --command-id RunShellScript \
          --scripts "test -f /tmp/psql_init_done && echo DONE || echo PENDING" \
          --query "value[0].message" -o tsv 2>/dev/null | grep -o 'DONE\|PENDING' || echo PENDING)

        if [ "$STATUS" = "DONE" ]; then
          echo "Init complete, deleting VM"
          az vm delete --yes \
            --resource-group ${azurerm_resource_group.db_rg.name} \
            --name ${var.psql_name}-init-vm
          exit 0
        fi

        LOG_TAIL=$(az vm run-command invoke \
          --resource-group ${azurerm_resource_group.db_rg.name} \
          --name ${var.psql_name}-init-vm \
          --command-id RunShellScript \
          --scripts "tail -n 5 /var/log/cloud-init-output.log 2>/dev/null || echo 'log not found yet'" \
          --query "value[0].message" -o tsv 2>/dev/null || echo "could not fetch log")

        echo "--- last 5 lines of /var/log/cloud-init-output.log ---"
        echo "$LOG_TAIL"
        echo "------------------------------------------------------"

        echo "Attempt $i: init not complete yet, retrying in 30s..."
        sleep 30
      done

      echo "Timed out waiting for init to complete"
      exit 1
    EOT
  }

  depends_on = [
    azurerm_linux_virtual_machine.psql_init
  ]
}
