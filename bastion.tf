#---------------------------------------------
# Azure Bastion + Linux VM Jumpbox
#---------------------------------------------
resource "time_sleep" "wait_for_vnet" {
  create_duration = "30s"

  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location
  sku                 = "Developer"
  virtual_network_id  = azurerm_virtual_network.vnet.id

  depends_on = [
    azurerm_virtual_network.vnet,
    time_sleep.wait_for_vnet
  ]
}

# Small jump box VM in the same VNet
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "psql-jumpbox"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location
  size                = "Standard_B1s" # cheapest, fine for a jump box
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.jumpbox.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
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

  custom_data = base64encode(file("${path.module}/scripts/jumpbox_init.sh"))
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "jumpbox-nic"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}
