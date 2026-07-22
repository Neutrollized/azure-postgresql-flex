# splits comma-delimited string list of extensions in uppercase into an actual list in lowercase
# i.e. "POSTGIS, POSTGIS_RASTER" -> ["postgis", "postgis_raster"]
locals {
  allowed_extensions_list = [for ext in split(",", var.allowed_extensions) : trimspace(lower(ext))]

  # everything except the templated extensions file will be discovered dynamically
  extra_sql_files = fileset("${path.module}/scripts/sql", "*.sql")

  sql_files = merge(
    {
      "00_extensions.sql" = templatefile("${path.module}/scripts/sql/00_extensions.sql.tpl", {
        allowed_extensions = local.allowed_extensions_list
      })
    },
    length(var.sql_schema_names) > 0 ? {
      "01_schemas.sql" = templatefile("${path.module}/scripts/sql/01_schemas.sql.tpl", {
        schema_names = var.sql_schema_names
      })
    } : {},
    length(var.sql_roles) > 0 ? {
      "02a_roles.sql" = templatefile("${path.module}/scripts/sql/02a_roles.sql.tpl", {
        roles = var.sql_roles
      })
    } : {},
    length(var.sql_user_role_grants) > 0 ? {
      "02b_role_grants.sql" = templatefile("${path.module}/scripts/sql/02b_role_grants.sql.tpl", {
        user_role_grants = var.sql_user_role_grants
      })
    } : {},
    length(var.sql_db_conn_grants) > 0 ? {
      "03_db_conn_grants.sql" = templatefile("${path.module}/scripts/sql/03_db_conn_grants.sql.tpl", {
        db_conn_grants = var.sql_db_conn_grants
      })
    } : {},
    length(var.sql_schema_privileges) > 0 ? {
      "04a_schema_privs.sql" = templatefile("${path.module}/scripts/sql/04a_schema_privs.sql.tpl", {
        schema_privileges = var.sql_schema_privileges
      })
    } : {},
    length(var.sql_default_schema_privileges) > 0 ? {
      "04b_default_schema_privs.sql" = templatefile("${path.module}/scripts/sql/04b_default_schema_privs.sql.tpl", {
        default_schema_privileges = var.sql_default_schema_privileges
      })
    } : {},
    length(var.sql_database_tables) > 0 ? {
      "05a_create_tables.sql" = templatefile("${path.module}/scripts/sql/05a_create_tables.sql.tpl", {
        database_tables = var.sql_database_tables
      })
    } : {},
    length(var.sql_triggers) > 0 ? {
      "05b_triggers.sql" = templatefile("${path.module}/scripts/sql/05b_triggers.sql.tpl", {
        triggers               = var.sql_triggers
        unique_trigger_schemas = distinct([for k, v in var.sql_triggers : v.schema])
      })
    } : {},
    { for fname in local.extra_sql_files : fname => file("${path.module}/scripts/sql/${fname}") }
  )
}

data "cloudinit_config" "psql_init" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      write_files = [
        for fname, content in local.sql_files : {
          path        = "/opt/psql_init/sql/${fname}"
          permissions = "0644"
          content     = content
        }
      ]
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/psql_init.sh", {
      db_host                = azurerm_postgresql_flexible_server.psql.fqdn
      db_name                = azurerm_postgresql_flexible_server_database.gis_db.name
      akv_name               = azurerm_key_vault.kv.name
      akv_secret_db_username = azurerm_key_vault_secret.db_username.name
      akv_secret_db_password = azurerm_key_vault_secret.db_password.name
    })
  }
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

  custom_data = data.cloudinit_config.psql_init.rendered

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

resource "azurerm_role_assignment" "vm_identity" {
  count                = var.enable_initialization ? 1 : 0
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.psql_init[count.index].identity[0].principal_id
}

# this sets the Linux VM OS disk and NIC to delete when VM is deleted
resource "azapi_update_resource" "vm_os_disk_delete" {
  count     = var.enable_initialization ? 1 : 0
  type      = "Microsoft.Compute/virtualMachines@2023-09-01"
  name      = azurerm_linux_virtual_machine.psql_init[count.index].name
  parent_id = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}/resourceGroups/${azurerm_resource_group.db_rg.name}"

  body = {
    properties = {
      storageProfile = {
        osDisk = {
          deleteOption = "Delete"
        }
      }
      networkProfile = {
        networkInterfaces = [
          {
            id = azurerm_network_interface.psql_init[count.index].id
            properties = {
              deleteOption = "Delete"
            }
          }
        ]
      }
    }
  }

  depends_on = [
    azurerm_linux_virtual_machine.psql_init
  ]
}


# cleanup psql init vm
resource "null_resource" "destroy_init_vm" {
  count = var.enable_initialization ? 1 : 0

  triggers = {
    always_run = timestamp()
  }

  # simple, static sleep timer
  #provisioner "local-exec" {
  #  command = "sleep 300 && az vm delete --yes --resource-group ${azurerm_resource_group.db_rg.name} --name ${var.psql_name}-init-vm"
  #}

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      for i in $(seq 1 20); do
        LOG_TAIL=$(az vm run-command invoke \
          --resource-group ${azurerm_resource_group.db_rg.name} \
          --name ${var.psql_name}-init-vm \
          --command-id RunShellScript \
          --scripts "tail -n 10 /var/log/cloud-init-output.log 2>/dev/null || echo 'log not found yet'" \
          --query "value[0].message" -o tsv || echo "az vm run-command invoke call failed")

        echo "--- last 10 lines of /var/log/cloud-init-output.log ---"
        echo "$LOG_TAIL"
        echo "------------------------------------------------------"

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

        echo "Attempt $i: init not complete yet, retrying in 15s..."
        sleep 15
      done

      echo "Timed out waiting for init to complete"
      exit 1
    EOT
  }

  depends_on = [
    azurerm_linux_virtual_machine.psql_init
  ]
}
