###----------------------------------------
# Virtual Network (VNet)
# https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
#------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "postgres-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.db_rg.name
  address_space       = var.network_cidrs.vnet
}

resource "azurerm_subnet" "pe" {
  name                 = "pe-subnetnet"
  resource_group_name  = azurerm_resource_group.db_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.network_cidrs.pe

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.db_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.network_cidrs.app

  service_endpoints = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet" "db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.db_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.network_cidrs.db

  service_endpoints = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}


###----------------------------------------
# Network Security Groups (NSG)
# https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-network#requirement-121
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group#security_rule
# defaults rules: AllowVnetInBound, AllowAzureLoadBalancerInBound, DenyAllInBound
#------------------------------------------
resource "azurerm_network_security_group" "postgres_db_nsg" {
  name                = "postgresqlDbSubnetsNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.db_rg.name

  security_rule {
    name                       = "allow-app-ingress"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_subnet.app.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.db.address_prefixes[0]
  }

  security_rule {
    name                       = "deny-non-bastion-app-ingress"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "postgres_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.postgres_db_nsg.id
}

resource "azurerm_network_security_group" "app_nsg" {
  name                = "appSubnetNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.db_rg.name

  security_rule {
    name                       = "allow-bastion-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = azurerm_subnet.app.address_prefixes[0]
  }
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_network_security_group" "pe_nsg" {
  name                = "peSubnetNSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.db_rg.name

  security_rule {
    name                       = "allow-pe-access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = azurerm_subnet.pe.address_prefixes[0]
  }
}

resource "azurerm_subnet_network_security_group_association" "pe_nsg_assoc" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe_nsg.id
}
