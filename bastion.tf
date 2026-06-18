#---------------------------------------------
# Azure Bastion
#---------------------------------------------
resource "azurerm_public_ip" "bastion" {
  name                = "bastion_ext_ip"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  resource_group_name = azurerm_resource_group.db_rg.name
  location            = var.location
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
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
